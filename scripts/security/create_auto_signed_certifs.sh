#!/bin/bash
# Cleanup files
rm -f *.crt *.csr *_creds *.jks *.srl *.key *.pem *.der *.p12 *.log

# Generate CA key
openssl req -new -x509 -keyout snakeoil-ca-1.key -out snakeoil-ca-1.crt -days 365 -subj '/CN=ca1.test.confluent.io/OU=TEST/O=CONFLUENT/L=PARIS/ST=FR/C=EU' -passin pass:confluent -passout pass:confluent

users=(kafka-a-01 kafka-a-02 kafka-a-03 zook-a-01 zook-a-02 zook-a-03 kafka-ui-a-01 mds)
echo "Creating certificates"
for user in "${users[@]}"; do
  i=${user//-/_}
  # Create host keystore
  keytool -genkey -noprompt \
    -alias $user \
    -dname "CN=$user,OU=TEST,O=CONFLUENT,L=PARIS,S=FR,C=EU" \
    -ext "SAN=dns:$user,dns:localhost" \
    -keystore kafka.$user.keystore.jks \
    -keyalg RSA \
    -storepass confluent \
    -keypass confluent \
    -storetype pkcs12

  # Create the certificate signing request (CSR)
  keytool -keystore kafka.$user.keystore.jks -alias $user -certreq -file $user.csr -storepass confluent -keypass confluent -ext "SAN=dns:$user,dns:localhost"
  #openssl req -in $user.csr -text -noout

  # Enables 'confluent login --ca-cert-path /etc/kafka/secrets/snakeoil-ca-1.crt --url https://kafka1:8091'
  DNS_ALT_NAMES=$(printf '%s\n' "DNS.1 = $user" "DNS.2 = localhost")
  if [[ "$user" == "mds" ]]; then
    DNS_ALT_NAMES=$(printf '%s\n' "$DNS_ALT_NAMES" "DNS.3 = kafka-a-01" "DNS.4 = kafka-a-02" "DNS.5 = kafka-a-03")
  fi

  # Sign the host certificate with the certificate authority (CA)
  # Set a random serial number (avoid problems from using '-CAcreateserial' when parallelizing certificate generation)
  CERT_SERIAL=$(awk -v seed="$RANDOM" 'BEGIN { srand(seed); printf("0x%.4x%.4x%.4x%.4x\n", rand()*65535 + 1, rand()*65535 + 1, rand()*65535 + 1, rand()*65535 + 1) }')
  openssl x509 -req -CA ./snakeoil-ca-1.crt -CAkey ./snakeoil-ca-1.key -in $user.csr -out $user-ca1-signed.crt -sha256 -days 365 -set_serial ${CERT_SERIAL} -passin pass:confluent -extensions v3_req -extfile <(
    cat <<EOF
    [req]
    distinguished_name = req_distinguished_name
    x509_extensions = v3_req
    prompt = no
    [req_distinguished_name]
    CN = $user
    [v3_req]
    extendedKeyUsage = serverAuth, clientAuth
    subjectAltName = @alt_names
    [alt_names]
    $DNS_ALT_NAMES
EOF
  )
  #openssl x509 -noout -text -in $user-ca1-signed.crt

  # Sign and import the CA cert into the keystore
  keytool -noprompt -keystore kafka.$user.keystore.jks -alias snakeoil-caroot -import -file ./snakeoil-ca-1.crt -storepass confluent -keypass confluent
  #keytool -list -v -keystore kafka.$user.keystore.jks -storepass confluent

  # Sign and import the host certificate into the keystore
  keytool -noprompt -keystore kafka.$user.keystore.jks -alias $user -import -file $user-ca1-signed.crt -storepass confluent -keypass confluent -ext "SAN=dns:$user,dns:localhost"
  #keytool -list -v -keystore kafka.$user.keystore.jks -storepass confluent

  # Create truststore and import the CA cert
  keytool -noprompt -keystore kafka.$user.truststore.jks -alias snakeoil-caroot -import -file ./snakeoil-ca-1.crt -storepass confluent -keypass confluent

  # Save creds
  echo "confluent" >${i}_sslkey_creds
  echo "confluent" >${i}_keystore_creds
  echo "confluent" >${i}_truststore_creds

  # Create pem files and keys used for Schema Registry HTTPS testing
  #   openssl x509 -noout -modulus -in client.certificate.pem | openssl md5
  #   openssl rsa -noout -modulus -in client.key | openssl md5
  #   echo "GET /" | openssl s_client -connect localhost:8085/subjects -cert client.certificate.pem -key client.key -tls1
  keytool -export -alias $user -file $user.der -keystore kafka.$user.keystore.jks -storepass confluent
  openssl x509 -inform der -in $user.der -out $user.certificate.pem
  keytool -importkeystore -srckeystore kafka.$user.keystore.jks -destkeystore $user.keystore.p12 -deststoretype PKCS12 -deststorepass confluent -srcstorepass confluent -noprompt
  openssl pkcs12 -in $user.keystore.p12 -nodes -nocerts -out $user.key -passin pass:confluent

  "logs/certs-create-$user.log" 2>&1 &&
    echo "Created certificates for $user"
done


create_certificates(){
  local DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

  # Generate keys and certificates used for SSL
  echo -e "Generate keys and certificates used for SSL (see ${DIR}/security)"
  # Install findutils to be able to use 'xargs' in the certs-create.sh script
  docker run -v ${DIR}/../security/:/etc/kafka/secrets/ -u0 $REPOSITORY/cp-server:${CONFLUENT_DOCKER_TAG} bash -c "yum -y install findutils; cd /etc/kafka/secrets && ./certs-create.sh && chown -R $(id -u $USER):$(id -g $USER) /etc/kafka/secrets"

  # Generating public and private keys for token signing
  echo "Generating public and private keys for token signing"
  docker run -v ${DIR}/../security/:/etc/kafka/secrets/ -u0 $REPOSITORY/cp-server:${CONFLUENT_DOCKER_TAG} bash -c "mkdir -p /etc/kafka/secrets/keypair; openssl genrsa -out /etc/kafka/secrets/keypair/keypair.pem 2048; openssl rsa -in /etc/kafka/secrets/keypair/keypair.pem -outform PEM -pubout -out /etc/kafka/secrets/keypair/public.pem && chown -R $(id -u $USER):$(id -g $USER) /etc/kafka/secrets/keypair"

  # Enable Docker appuser to read files when created by a different UID
  echo -e "Setting insecure permissions on some files in ${DIR}/../security for demo purposes\n"
  chmod 644 ${DIR}/../security/keypair/keypair.pem
  chmod 644 ${DIR}/../security/*.key
}

create_certificates