#!/bin/sh

NEXUS_DEFAULT_PASSWORD=admin123
#NEXUS_PASSWORD=test
#NEXUS_EMAIL=flavio.aielafdasf2@swisscom.com
#DOCKER_REPOSITORY_NAME=default
#DOCKER_REPOSITORY_PORT=5000

# Wait for script listing
until curl -sf -X GET -u admin:${NEXUS_DEFAULT_PASSWORD} 'http://localhost:8081/service/siesta/rest/v1/script'; do echo "Waiting for nexus to start ..."; sleep 7; done

# Change admin password
if [ -n "${NEXUS_PASSWORD}" ];then
   curl -v -X POST -u admin:${NEXUS_DEFAULT_PASSWORD} --header "Content-Type: application/json" 'http://localhost:8081/service/siesta/rest/v1/script' -d "{\"name\":\"changeadminpassword\",\"type\":\"groovy\",\"content\":\"security.securitySystem.changePassword('admin', '${NEXUS_PASSWORD}')\"}"
   curl -v -X POST -u admin:${NEXUS_DEFAULT_PASSWORD} --header "Content-Type: text/plain" "http://localhost:8081/service/siesta/rest/v1/script/changeadminpassword/run"
   curl -v -X DELETE -u admin:${NEXUS_DEFAULT_PASSWORD} 'http://localhost:8081/service/siesta/rest/v1/script/changeadminpassword'
fi

# Change admin email
if [ -n "${NEXUS_EMAIL}" ];then
   curl -v -X POST -u admin:${NEXUS_PASSWORD} --header "Content-Type: application/json" 'http://localhost:8081/service/siesta/rest/v1/script' -d "{\"name\":\"changeadminemail\",\"type\":\"groovy\",\"content\":\"def user = security.securitySystem.getUser('admin');user.setEmailAddress('${NEXUS_EMAIL}');security.securitySystem.updateUser(user);\"}"
   curl -v -X POST -u admin:${NEXUS_PASSWORD} --header "Content-Type: text/plain" "http://localhost:8081/service/siesta/rest/v1/script/changeadminemail/run"
   curl -v -X DELETE -u admin:${NEXUS_PASSWORD} 'http://localhost:8081/service/siesta/rest/v1/script/changeadminemail'
fi

# Add docker repository
if [ -n "${DOCKER_REPOSITORY_NAME}" ] && [ -n "${DOCKER_REPOSITORY_PORT}" ];then
   curl -v -X POST -u admin:${NEXUS_PASSWORD} --header "Content-Type: application/json" 'http://localhost:8081/service/siesta/rest/v1/script' -d "{\"name\":\"${DOCKER_REPOSITORY_NAME}\",\"type\":\"groovy\",\"content\":\"repository.createDockerHosted('${DOCKER_REPOSITORY_NAME}', ${DOCKER_REPOSITORY_PORT}, null, 'default', true, false)\"}"
   curl -v -X POST -u admin:${NEXUS_PASSWORD} --header "Content-Type: text/plain" "http://localhost:8081/service/siesta/rest/v1/script/${DOCKER_REPOSITORY_NAME}/run"
   curl -v -X DELETE -u admin:${NEXUS_PASSWORD} 'http://localhost:8081/service/siesta/rest/v1/script/${DOCKER_REPOSITORY_NAME}'
fi
