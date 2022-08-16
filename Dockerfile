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

FROM registry.access.redhat.com/ubi9/ubi-minimal

LABEL name="Nexus Repository Manager" \
      maintainer="Sonatype <support@sonatype.com>" \
      vendor=Sonatype \
      version="3.41.0-01" \
      release="3.41.0" \
      url="https://sonatype.com" \
      summary="The Nexus Repository Manager server \
          with universal support for popular component formats." \
      description="The Nexus Repository Manager server \
          with universal support for popular component formats." \
      run="docker run -d --name NAME \
          -p 8081:8081 \
          IMAGE" \
      stop="docker stop NAME" \
      com.sonatype.license="Apache License, Version 2.0" \
      com.sonatype.name="Nexus Repository Manager base image" \
      io.k8s.description="The Nexus Repository Manager server \
          with universal support for popular component formats." \
      io.k8s.display-name="Nexus Repository Manager" \
      io.openshift.expose-services="8081:8081" \
      io.openshift.tags="Sonatype,Nexus,Repository Manager"

ARG NEXUS_VERSION=3.41.0-01
ARG NEXUS_DOWNLOAD_URL=https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz
ARG NEXUS_DOWNLOAD_SHA256_HASH=ce265e627a665f9e833bf9c6e15a58c739882eb753863062f9e42e83e6f0d844

# configure nexus runtime
ENV SONATYPE_DIR=/opt/sonatype
ENV NEXUS_HOME=${SONATYPE_DIR}/nexus \
    NEXUS_DATA=/nexus-data \
    NEXUS_CONTEXT='' \
    SONATYPE_WORK=${SONATYPE_DIR}/sonatype-work \
    DOCKER_TYPE='rh-docker'

RUN microdnf update -y \
    && microdnf --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y java-1.8.0-openjdk-headless tar \
    && microdnf clean all \
    && groupadd --gid 200 -r nexus \
    && useradd --uid 200 -r nexus -g nexus

WORKDIR ${SONATYPE_DIR}

RUN curl -L ${NEXUS_DOWNLOAD_URL} | tar -xz \
    && mv nexus-${NEXUS_VERSION} $NEXUS_HOME \
    && mv ${SONATYPE_WORK}/nexus3 ${NEXUS_DATA} \
    && ln -s ${NEXUS_DATA} ${SONATYPE_WORK}/nexus3 \
    && chown -R nexus:nexus ${SONATYPE_WORK}

VOLUME ${NEXUS_DATA}

EXPOSE 8081
USER nexus

ENV INSTALL4J_ADD_VM_PARAMS="-Xms2703m -Xmx2703m -XX:MaxDirectMemorySize=2703m -Djava.util.prefs.userRoot=${NEXUS_DATA}/javaprefs"

CMD ["sh", "-c", "${NEXUS_HOME}/bin/nexus run"]
