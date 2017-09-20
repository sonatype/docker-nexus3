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

ADD solo.json /var/chef/solo.json

RUN curl -L https://www.getchef.com/chef/install.sh | bash
RUN chef-solo --recipe-url https://s3.amazonaws.com/int-public/nxrm-cookbook.tar.gz --json-attributes /var/chef/solo.json

EXPOSE 8081
USER nexus

CMD ["/opt/sonatype/start-nexus3.sh"]