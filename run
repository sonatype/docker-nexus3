#!/bin/bash
set -xe

if [ ! -e ${SSL_WORK}/*.key.pem ] || [ ! -e ${SSL_WORK}/*.crt.pem ]; then
  echo ".key.pem & .crt.pem are required in $SSL_WORK folder"
  exit 1
fi

## cf: https://wiki.eclipse.org/Jetty/Howto/Configure_SSL
#### Generate pkcs12 file ####
openssl pkcs12 -export \
  -inkey ${SSL_WORK}/*.key.pem \
  -in ${SSL_WORK}/*chain.pem \
  -out ${NEXUS_DATA}etc/ssl/jetty.pkcs12 \
  -passout pass:${SSL_STOREPASS}

#### Generate keystore ####
keytool -importkeystore -noprompt \
  -srckeystore ${NEXUS_DATA}etc/ssl/jetty.pkcs12 \
  -srcstoretype PKCS12 \
  -srcstorepass ${SSL_STOREPASS} \
  -deststorepass ${SSL_STOREPASS} \
  -keypass ${SSL_KEYPASS} \
  -destkeystore ${NEXUS_DATA}etc/ssl/server-keystore.jks

#### Run nexus ####
/bin/sh -c ${SONATYPE_DIR}/start-nexus-repository-manager.sh
