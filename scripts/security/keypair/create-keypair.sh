#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

openssl genrsa -out keypair.pem 2048
openssl rsa -in keypair.pem -outform PEM -pubout -out public.pem