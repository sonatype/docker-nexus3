# Copyright (c) 2016-present Sonatype, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM registry.access.redhat.com/ubi8/ubi

LABEL vendor=Sonatype \
      maintainer="Sonatype <cloud-ops@sonatype.com>" \
      com.sonatype.license="Apache License, Version 2.0" \
      com.sonatype.name="Nexus Repository Manager base image"


#### Some args to build the docker --build-args
ENV SSL_STOREPASS=changeit
ENV SSL_KEYPASS=changeit
ENV SSL_DOMAIN_NAME="elium.io"

ARG NEXUS_VERSION=3.19.1-01
ARG NEXUS_DOWNLOAD_URL=https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz
ARG NEXUS_DOWNLOAD_SHA256_HASH=7a2e62848abeb047c99e114b3613d29b4afbd635b03a19842efdcd6b6cb95f4e

# configure nexus runtime
ENV SONATYPE_DIR=/opt/sonatype
ENV NEXUS_HOME=${SONATYPE_DIR}/nexus \
    NEXUS_DATA=/nexus-data \
    NEXUS_CONTEXT='' \
    SONATYPE_WORK=${SONATYPE_DIR}/sonatype-work \
    DOCKER_TYPE='rh-docker'

ENV SSL_WORK /etc/ssl/private

ARG NEXUS_REPOSITORY_MANAGER_COOKBOOK_VERSION="release-0.5.20190212-155606.d1afdfe"
ARG NEXUS_REPOSITORY_MANAGER_COOKBOOK_URL="https://github.com/sonatype/chef-nexus-repository-manager/releases/download/${NEXUS_REPOSITORY_MANAGER_COOKBOOK_VERSION}/chef-nexus-repository-manager.tar.gz"

ADD solo.json.erb /var/chef/solo.json.erb

# Install OpenSSL
RUN yum install -y --disableplugin=subscription-manager  openssl openssl-devel

# Install using chef-solo
# Chef version locked to avoid needing to accept the EULA on behalf of whomever builds the image
RUN yum install -y --disableplugin=subscription-manager hostname procps \
    && curl -L https://www.getchef.com/chef/install.sh | bash -s -- -v 14.12.9 \
    && /opt/chef/embedded/bin/erb /var/chef/solo.json.erb > /var/chef/solo.json \
    && chef-solo \
       --recipe-url ${NEXUS_REPOSITORY_MANAGER_COOKBOOK_URL} \
       --json-attributes /var/chef/solo.json \
    && rpm -qa *chef* | xargs rpm -e \
    && rm -rf /etc/chef \
    && rm -rf /opt/chefdk \
    && rm -rf /var/cache/yum \
    && rm -rf /var/chef \
    && yum clean all

#CUSTOM
#https://help.sonatype.com/repomanager3/security/configuring-ssl#ConfiguringSSL-ServingSSLDirectly

RUN mkdir -p ${SONATYPE_WORK}etc/ssl
RUN mkdir -p ${NEXUS_DATA}etc/ssl

### Edit nexus.properties ###
RUN echo "application-port-ssl=8443" >> ${NEXUS_DATA}etc/nexus.properties
RUN sed -i -e '/nexus-args=/ s/=.*/=${jetty.etc}\/jetty.xml,${jetty.etc}\/jetty-http.xml,${jetty.etc}\/jetty-https.xml,${jetty.etc}\/jetty-requestlog.xml,${jetty.etc}\/jetty-http-redirect-to-https.xml/' ${NEXUS_DATA}etc/nexus.properties
RUN echo "ssl.etc=\${karaf.data}/etc/ssl" >> ${NEXUS_DATA}etc/nexus.properties
RUN sed -i 's/<Set name="KeyStorePath">.*<\/Set>/<Set name="KeyStorePath">\/opt\/nexus\/etc\/ssl\/keystore.jks<\/Set>/g' /${NEXUS_HOME}/etc/jetty-https.xml \
  && sed -i 's/<Set name="KeyStorePassword">.*<\/Set>/<Set name="KeyStorePassword">changeit<\/Set>/g' ${NEXUS_HOME}/etc/jetty-https.xml \
  && sed -i 's/<Set name="KeyManagerPassword">.*<\/Set>/<Set name="KeyManagerPassword">changeit<\/Set>/g' ${NEXUS_HOME}/etc/jetty-https.xml \
  && sed -i 's/<Set name="TrustStorePath">.*<\/Set>/<Set name="TrustStorePath">\/opt\/nexus\/etc\/ssl\/keystore.jks<\/Set>/g' ${NEXUS_HOME}/etc/jetty-https.xml \
  && sed -i 's/<Set name="TrustStorePassword">.*<\/Set>/<Set name="TrustStorePassword">changeit<\/Set>/g' ${NEXUS_HOME}/etc/jetty-https.xml

VOLUME ${NEXUS_DATA}
VOLUME ${SSL_WORK}

#### http, https, https for docker group, https for hosted docker hub ####
EXPOSE 8081 5000 5001
USER nexus

ENV INSTALL4J_ADD_VM_PARAMS="-Xms1200m -Xmx1200m -XX:MaxDirectMemorySize=2g -Djava.util.prefs.userRoot=${NEXUS_DATA}/javaprefs"

CMD bin/run
CMD ["sh", "-c", "${SONATYPE_DIR}/start-nexus-repository-manager.sh"]
