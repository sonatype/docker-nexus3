FROM       java:8-jre-alpine
MAINTAINER Sonatype <cloud-ops@sonatype.com>

ENV NEXUS_DATA /nexus-data
ENV NEXUS_VERSION 3.0.1-01

# install nexus
RUN apk update && apk add openssl && rm -fr /var/cache/apk/*
RUN mkdir -p /opt/sonatype/ \
  && wget https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz -O - \
  | tar zx -C /opt/sonatype/ \
  && mv /opt/sonatype/nexus-${NEXUS_VERSION} /opt/sonatype/nexus

## configure nexus runtime env
RUN sed \
    -e "s|karaf.home=.|karaf.home=/opt/sonatype/nexus|g" \
    -e "s|karaf.base=.|karaf.base=/opt/sonatype/nexus|g" \
    -e "s|karaf.etc=etc|karaf.etc=/opt/sonatype/nexus/etc|g" \
    -e "s|java.util.logging.config.file=etc|java.util.logging.config.file=/opt/sonatype/nexus/etc|g" \
    -e "s|karaf.data=data|karaf.data=${NEXUS_DATA}|g" \
    -e "s|java.io.tmpdir=data/tmp|java.io.tmpdir=${NEXUS_DATA}/tmp|g" \
    -i /opt/sonatype/nexus/bin/nexus.vmoptions

## create nexus user
RUN echo "nexus:x:200:200:nexus role account:${NEXUS_DATA}:/bin/false" >> /etc/passwd
RUN echo "nexus:x:200:" >> /etc/group
RUN echo "nexus:!::0:::::" >> /etc/shadow

## prevent warning: /opt/sonatype/nexus/etc/org.apache.karaf.command.acl.config.cfg (Permission denied)
RUN chown nexus:nexus /opt/sonatype/nexus/etc/

COPY entrypoint.sh /

VOLUME ${NEXUS_DATA}

EXPOSE 8081
WORKDIR /opt/sonatype/nexus

ENV JAVA_MAX_MEM 1200m
ENV JAVA_MIN_MEM 1200m
ENV EXTRA_JAVA_OPTS ""

ENTRYPOINT ["/entrypoint.sh"]
