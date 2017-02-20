#!/bin/bash

# change java memory options if env vars exist
[[ -n ${JAVA_MIN_MEM} ]] && TF="$(mktemp)" && cat ${NEXUS_HOME}/bin/nexus.vmoptions | sed -e "s|Xms.*|Xms${JAVA_MIN_MEM}|g" > ${TF} && cat ${TF} > ${NEXUS_HOME}/bin/nexus.vmoptions && rm -f ${TF}
[[ -n ${JAVA_MAX_MEM} ]] && TF="$(mktemp)" && cat ${NEXUS_HOME}/bin/nexus.vmoptions | sed -e "s|Xmx.*|Xmx${JAVA_MAX_MEM}|g" > ${TF} && cat ${TF} > ${NEXUS_HOME}/bin/nexus.vmoptions && rm -f ${TF}

# clean lock, tmp and cache dirs
rm -rf ${NEXUS_DATA}/lock ${NEXUS_DATA}/tmp/ ${NEXUS_DATA}/cache/

# execute
exec "$@"
