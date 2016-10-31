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

FROM       centos:centos7

MAINTAINER Sonatype <cloud-ops@sonatype.com>

LABEL vendor="Sonatype" \
      com.sonatype.license="Apache License, Version 2.0" \
      com.sonatype.name="Nexus Repository Manager base image"

RUN yum install -y --setopt=tsflags=nodocs curl tar && \
    yum clean all

# install Oracle JRE
ENV JAVA_HOME=/opt/java \
    JAVA_VERSION_MAJOR=8 \
    JAVA_VERSION_MINOR=102 \
    JAVA_VERSION_BUILD=14

RUN curl --remote-name --fail --silent --location --retry 3 \
        --header "Cookie: oraclelicense=accept-securebackup-cookie; " \
        http://download.oracle.com/otn-pub/java/jdk/${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-b${JAVA_VERSION_BUILD}/jdk-${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-linux-x64.rpm && \
    yum localinstall -y jdk-${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-linux-x64.rpm && \
    yum clean all && \
    rm jdk-${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-linux-x64.rpm

# install nexus
ENV NEXUS_DATA=/nexus-data \
    NEXUS_HOME=/opt/sonatype/nexus \
    NEXUS_VERSION=3.0.2-02 \
    NEXUS_CONTEXT='' \
    USER_NAME=nexus \
    USER_UID=200

RUN mkdir -p ${NEXUS_HOME} && \
    curl --fail --silent --location --retry 3 \
      https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz \
      | gunzip \
      | tar x -C ${NEXUS_HOME} --strip-components=1 nexus-${NEXUS_VERSION}

## configure nexus runtime env
RUN sed \
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

RUN useradd -u ${USER_UID} -r -g 0 -m -d ${NEXUS_DATA} -s /bin/false \
            -c "nexus role account" ${USER_NAME}

VOLUME ${NEXUS_DATA}

USER ${USER_NAME}
WORKDIR ${NEXUS_HOME}

ENV JAVA_MAX_MEM=1200m \
    JAVA_MIN_MEM=1200m \
    EXTRA_JAVA_OPTS=""

EXPOSE 8081

CMD ["bin/nexus", "run"]
