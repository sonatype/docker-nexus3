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

FROM alpine:latest

MAINTAINER Sonatype <cloud-ops@sonatype.com>

LABEL vendor=Sonatype \
      com.sonatype.license="Apache License, Version 2.0" \
      com.sonatype.name="Nexus Repository Manager base image"

ENV JAVA_HOME /usr/lib/jvm/java-1.8-openjdk/jre
ENV NEXUS_CONTEXT ""
ENV NEXUS_DATA /nexus-data
ENV NEXUS_VERSION 3.0.2-02

# Add local files and according directories to image
ADD files /

# Packages
RUN apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/main && \
    apk add --no-cache --repository  http://dl-cdn.alpinelinux.org/alpine/edge/community && \
    apk update && \
    apk upgrade && \
    apk add ca-certificates supervisor openjdk8 bash curl tar && \
    rm -rf /var/cache/apk/*

# Nexus
RUN echo "Installing Nexus ${NEXUS_VERSION} ..." && \
    mkdir -p /opt/sonatype/nexus && \
    curl -sSL --retry 3 https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz | tar -C /opt/sonatype/nexus -xvz --strip-components=1 nexus-${NEXUS_VERSION} && \
    addgroup -S nexus && \
    adduser -G nexus -h ${NEXUS_DATA} -SD nexus && \
    chmod -R +x /usr/local/bin && \
    chown -R nexus:nexus /opt/sonatype/nexus && \
    sed \
    -e "s|karaf.home=.|karaf.home=/opt/sonatype/nexus|g" \
    -e "s|karaf.base=.|karaf.base=/opt/sonatype/nexus|g" \
    -e "s|karaf.etc=etc|karaf.etc=/opt/sonatype/nexus/etc|g" \
    -e "s|java.util.logging.config.file=etc|java.util.logging.config.file=/opt/sonatype/nexus/etc|g" \
    -e "s|karaf.data=data|karaf.data=${NEXUS_DATA}|g" \
    -e "s|java.io.tmpdir=data/tmp|java.io.tmpdir=${NEXUS_DATA}/tmp|g" \
    -i /opt/sonatype/nexus/bin/nexus.vmoptions && \
    sed \
    -e "s|nexus-context-path=/|nexus-context-path=/\${NEXUS_CONTEXT}|g" \
    -i /opt/sonatype/nexus/etc/org.sonatype.nexus.cfg

EXPOSE 8081 5000

USER nexus

VOLUME ${NEXUS_DATA}

WORKDIR /opt/sonatype/nexus

ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]

