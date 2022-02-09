#!/bin/bash

if [ -z "${NEXUS_ADMIN_INIT_PASSWORD}" ] || [ -d "${SONATYPE_WORK}/nexus3/db/security" ]; then
    ${SONATYPE_DIR}/start-nexus-repository-manager.sh
else
    SHIRO_PASSWORD=$(java -jar "${SHIRO_CLI_JAR}" -a SHA-512 -f shiro1 "${NEXUS_ADMIN_INIT_PASSWORD}")
    "${SONATYPE_DIR}/start-nexus-repository-manager.sh" &
    while ! curl -f localhost:8081 > /dev/null 2>&1; do
        sleep 1
    done
    NEXUS_PID=$(ps aux | grep nexus | grep -v grep | awk '{print $2}')
    kill $NEXUS_PID
    java -jar ${SONATYPE_DIR}/nexus/lib/support/nexus-orient-console.jar "connect plocal:${SONATYPE_WORK}/nexus3/db/security admin admin; update user SET password=\"${SHIRO_PASSWORD}\", status=\"active\" UPSERT WHERE id=\"admin\""
    "${SONATYPE_DIR}/start-nexus-repository-manager.sh"
fi
