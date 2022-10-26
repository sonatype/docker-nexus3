#!/usr/bin/env bash
#
# Copyright (c) 2017-present Sonatype, Inc.
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
#

# prerequisites:
# * software:
#   * https://github.com/redhat-openshift-ecosystem/openshift-preflight
#   * https://podman.io/
# * environment variables:
#   * VERSION of the docker image  to build for the red hat registry
#   * REGISTRY_LOGIN from Red Hat config page for image
#   * REGISTRY_PASSWORD from Red Hat config page for image
#   * API_TOKEN from red hat token/account page for API access

set -x # log commands as they execute
set -e # stop execution on the first failed command

DOCKERFILE=Dockerfile.rh.ubi

# from config/scanning page at red hat
CERT_PROJECT_ID=5e61d90a38776799eb517bd2

REPOSITORY="quay.io"
IMAGE_TAG="${REPOSITORY}/redhat-isv-containers/${CERT_PROJECT_ID}:${VERSION}"
IMAGE_LATEST="${REPOSITORY}/redhat-isv-containers/${CERT_PROJECT_ID}:latest"

AUTHFILE="${HOME}/.docker/config.json"

docker build -f "${DOCKERFILE}" -t "${IMAGE_TAG}" .
docker tag "${IMAGE_TAG}" "${IMAGE_LATEST}"

docker login "${REPOSITORY}" \
       -u "${REGISTRY_LOGIN}" \
       --password "${REGISTRY_PASSWORD}"

docker push "${IMAGE_TAG}"
docker push "${IMAGE_LATEST}"

preflight check container \
          "${IMAGE_TAG}" \
          --docker-config="${AUTHFILE}" \
          --submit \
          --certification-project-id="${CERT_PROJECT_ID}" \
          --pyxis-api-token="${API_TOKEN}"
