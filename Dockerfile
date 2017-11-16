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

FROM centos:centos7

MAINTAINER Sonatype <cloud-ops@sonatype.com>

LABEL vendor=Sonatype \
      com.sonatype.license="Apache License, Version 2.0" \
      com.sonatype.name="Nexus Repository Manager base image"

ARG NEXUS_VERSION=3.6.1-02
ARG NEXUS_DOWNLOAD_URL=https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz
ARG NEXUS_DOWNLOAD_SHA256_HASH=4a658996cf29ca2d4f9c8b3d3cff11bfc358d88f03495812d7814268f0b1259b

ENV JAVA_HOME=/opt/java \
    JAVA_VERSION_MAJOR=8 \
    JAVA_VERSION_MINOR=152 \
    JAVA_VERSION_BUILD=16 \
    JAVA_DOWNLOAD_HASH=aa0333dd3019491ca4f6ddbe78cdb6d0

ENV JAVA_URL=http://download.oracle.com/otn-pub/java/jdk/${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-b${JAVA_VERSION_BUILD}/${JAVA_DOWNLOAD_HASH}/server-jre-${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-linux-x64.tar.gz \
    JAVA_DOWNLOAD_SHA256_HASH=e8a341ce566f32c3d06f6d0f0eeea9a0f434f538d22af949ae58bc86f2eeaae4

# configure nexus runtime
ENV SONATYPE_DIR=/opt/sonatype
ENV NEXUS_HOME=${SONATYPE_DIR}/nexus \
    NEXUS_DATA=/nexus-data \
    NEXUS_CONTEXT='' \
    SONATYPE_WORK=${SONATYPE_DIR}/sonatype-work

ARG NEXUS_REPOSITORY_MANAGER_COOKBOOK_VERSION="release-0.5.20171115-163526.03915d6"
ARG NEXUS_REPOSITORY_MANAGER_COOKBOOK_URL="https://github.com/sonatype/chef-nexus-repository-manager/releases/download/${NEXUS_REPOSITORY_MANAGER_COOKBOOK_VERSION}/chef-nexus-repository-manager.tar.gz"

ADD solo.json.erb /var/chef/solo.json.erb

# Install using chef-solo
RUN curl -L https://www.getchef.com/chef/install.sh | bash \
    && /opt/chef/embedded/bin/erb /var/chef/solo.json.erb > /var/chef/solo.json \
    && chef-solo \
       --recipe-url ${NEXUS_REPOSITORY_MANAGER_COOKBOOK_URL} \
       --json-attributes /var/chef/solo.json \
    && rpm -qa *chef* | xargs rpm -e \
    && rpm --rebuilddb \
    && rm -rf /etc/chef \
    && rm -rf /opt/chefdk \
    && rm -rf /var/cache/yum \
    && rm -rf /var/chef

VOLUME ${NEXUS_DATA}

EXPOSE 8081
USER nexus

ENV INSTALL4J_ADD_VM_PARAMS="-Xms1200m -Xmx1200m -XX:MaxDirectMemorySize=2g -Djava.util.prefs.userRoot=${NEXUS_DATA}/javaprefs"

CMD ["sh", "-c", "${SONATYPE_DIR}/start-nexus-repository-manager.sh"]
