# AlpineLinux with a glibc-2.23 and Oracle Java 8
FROM alpine:3.4

MAINTAINER Sonatype <cloud-ops@sonatype.com>

# Java Version and other ENV
ENV JAVA_VERSION_MAJOR=8 \
    JAVA_VERSION_MINOR=92 \
    JAVA_VERSION_BUILD=14 \
    JAVA_PACKAGE=server-jre \
    JAVA_HOME=/opt/jdk \
    PATH=${PATH}:/opt/jdk/bin \
    GLIBC_VERSION=2.23-r3 \
    LANG=C.UTF-8 \
    NEXUS_DATA="/nexus-data" \
    NEXUS_VERSION="3.0.1-01" \
    JAVA_HOME="/opt/jdk" \
    JAVA_MAX_MEM="1200m" \
    JAVA_MIN_MEM="1200m" \
    EXTRA_JAVA_OPTS=""

# User and Group
RUN addgroup nexus && \
    adduser -S -u 200 -h ${NEXUS_DATA} -s /bin/false nexus && \
    addgroup nexus nexus

# Install Java JRE
RUN apk upgrade --update && \
    apk add --update curl ca-certificates bash && \
    for pkg in glibc-${GLIBC_VERSION} glibc-bin-${GLIBC_VERSION} glibc-i18n-${GLIBC_VERSION}; do curl -sSL https://github.com/andyshinn/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/${pkg}.apk -o /tmp/${pkg}.apk; done && \
    apk add --allow-untrusted /tmp/*.apk && \
    rm -v /tmp/*.apk && \
    ( /usr/glibc-compat/bin/localedef --force --inputfile POSIX --charmap UTF-8 C.UTF-8 || true ) && \
    echo "export LANG=C.UTF-8" > /etc/profile.d/locale.sh && \
    /usr/glibc-compat/sbin/ldconfig /lib /usr/glibc-compat/lib && \
    mkdir /opt && \
    curl -jksSLH "Cookie: oraclelicense=accept-securebackup-cookie" -o /tmp/java.tar.gz \
      http://download.oracle.com/otn-pub/java/jdk/${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-b${JAVA_VERSION_BUILD}/${JAVA_PACKAGE}-${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-linux-x64.tar.gz && \
    gunzip /tmp/java.tar.gz && \
    tar -C /opt -xf /tmp/java.tar && \
    apk del glibc-i18n && \
    ln -s /opt/jdk1.${JAVA_VERSION_MAJOR}.0_${JAVA_VERSION_MINOR} /opt/jdk && \
    find /opt/jdk/ -maxdepth 1 -mindepth 1 | grep -v jre | xargs rm -rf && \
    cd /opt/jdk/ && ln -s ./jre/bin ./bin && \
    rm -rf  /tmp/* /var/cache/apk/* && \
    echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf && \
    mkdir -p /opt/sonatype/nexus && \
    apk add --update tar=1.29-r0 && \
    curl --fail --silent --location --retry 3 https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz | \
      gunzip | \
      tar x -C /opt/sonatype/nexus --strip-components=1 nexus-${NEXUS_VERSION} && \
    chown -R nexus:nexus /opt/sonatype/nexus && \
    apk del curl && \
    sed \ 
      -e "s|karaf.home=.|karaf.home=/opt/sonatype/nexus|g" \
      -e "s|karaf.base=.|karaf.base=/opt/sonatype/nexus|g" \
      -e "s|karaf.etc=etc|karaf.etc=/opt/sonatype/nexus/etc|g" \
      -e "s|java.util.logging.config.file=etc|java.util.logging.config.file=/opt/sonatype/nexus/etc|g" \
      -e "s|karaf.data=data|karaf.data=${NEXUS_DATA}|g" \
      -e "s|java.io.tmpdir=data/tmp|java.io.tmpdir=${NEXUS_DATA}/tmp|g" \
      -i /opt/sonatype/nexus/bin/nexus.vmoptions

VOLUME ${NEXUS_DATA}

EXPOSE 8081
USER nexus
WORKDIR /opt/sonatype/nexus


CMD bin/nexus run
