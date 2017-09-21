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

ARG NEXUS_VERSION=3.5.2-01
ARG NEXUS_CHECKSUM=477969da1ea3a532247be628e5ca2b466c9653e88ba51d51a1609eacb0a45b4b

# configure nexus runtime
ENV SONATYPE_DIR=/opt/sonatype
ENV NEXUS_HOME=${SONATYPE_DIR}/nexus \
  NEXUS_DATA=/nexus-data \
  NEXUS_CONTEXT='' \
  SONATYPE_WORK=${SONATYPE_DIR}/sonatype-work

ADD solo_template.json /var/chef/solo_template.json

RUN sed -e "\
    s|NEXUS_VERSION|${NEXUS_VERSION}|g; \
    s|NEXUS_CHECKSUM|${NEXUS_CHECKSUM}|g; \
    s|SONATYPE_DIR|${SONATYPE_DIR}|g; \
    s|NEXUS_DATA|${NEXUS_DATA}|g; \
    s|NEXUS_CONTEXT|${NEXUS_CONTEXT}|g" \
    /var/chef/solo_template.json > /var/chef/solo.json

RUN curl -L https://www.getchef.com/chef/install.sh | bash
RUN chef-solo --recipe-url https://s3.amazonaws.com/int-public/nxrm-cookbook.tar.gz --json-attributes /var/chef/solo.json

VOLUME ${NEXUS_DATA}

EXPOSE 8081
USER nexus

WORKDIR ${NEXUS_HOME}

ENV INSTALL4J_ADD_VM_PARAMS="-Xms1200m -Xmx1200m -XX:MaxDirectMemorySize=2g -Djava.util.prefs.userRoot=${NEXUS_DATA}/javaprefs"

CMD ["bin/nexus", "run"]
