#!/bin/sh -e

[ -d "${NEXUS_DATA}" ] || mkdir -p "${NEXUS_DATA}"
chown -R nexus:nexus "${NEXUS_DATA}"

[ -n "${JAVA_MAX_MEM}" ] && sed -i "s/-Xmx.*/-Xmx${JAVA_MAX_MEM}/g" /opt/sonatype/nexus/bin/nexus.vmoptions
[ -n "${JAVA_MIN_MEM}" ] && sed -i "s/-Xms.*/-Xmx${JAVA_MIN_MEM}/g" /opt/sonatype/nexus/bin/nexus.vmoptions
[ -n "${EXTRA_JAVA_OPTS}" ] && echo "${EXTRA_JAVA_OPTS}" >> /opt/sonatype/nexus/bin/nexus.vmoptions

[ $# -eq 0 ] && \
    exec su -s /bin/sh -c '/opt/sonatype/nexus/bin/nexus run' nexus || \
    exec "$@"
