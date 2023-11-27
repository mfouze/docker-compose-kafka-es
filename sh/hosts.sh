#!/bin/bash

# Noms des conteneurs Docker Kafka
containers=("kafka-a-01" "kafka-a-02" "kafka-a-03" "zookeeper-a-01" "zookeeper-a-02" "zookeeper-a-03")

# Fichier hosts
hosts_file="/etc/hosts"
backup_hosts_file="/etc/hosts.bak"

# Création d'une sauvegarde de votre fichier hosts actuel
cp $hosts_file $backup_hosts_file

# Fonction pour ajouter une entrée au fichier hosts
add_to_hosts() {
    local ip=$1
    local hostname=$2
    if ! grep -q $hostname $hosts_file; then
        echo "$ip $hostname" >> $hosts_file
    else
        echo "L'entrée pour $hostname existe déjà dans $hosts_file. Aucune action requise."
    fi
}

# Itérer sur les conteneurs et les ajouter au fichier hosts
for container in "${containers[@]}"
do
    # Obtenir l'adresse IP du conteneur
    ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $container)
    
    # Vérifier si l'IP a été récupérée avec succès
    if [ -z "$ip" ]; then
        echo "L'adresse IP du conteneur $container n'a pas pu être trouvée."
    else
        # Ajouter ou mettre à jour l'entrée dans le fichier hosts
        add_to_hosts $ip $container
    fi
done

# Affichage du résultat
echo "Mise à jour du fichier hosts terminée."
cat $hosts_file
