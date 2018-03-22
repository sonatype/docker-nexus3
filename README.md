<!--

  Copyright (c) 2016-present Sonatype, Inc.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

-->

# Sonatype Nexus3 Docker: sonatype/nexus3

[![Join the chat at https://gitter.im/sonatype/nexus-developers](https://badges.gitter.im/sonatype/nexus-developers.svg)](https://gitter.im/sonatype/nexus-developers?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

A Dockerfile for Sonatype Nexus Repository Manager 3, based on CentOS.

* [Contribution Guidlines](#contribution-guidelines)
* [Running](#running)
* [Building the Nexus Repository Manager image](#building-the-nexus-repository-manager-image)
* [Chef Solo for Runtime and Application](#chef-solo-for-runtime-and-application)
* [Testing the Dockerfile](#testing-the-dockerfile)
* [Red Hat Certified Image](#red-hat-certified-image)
* [Notes](#notes)
  * [Persistent Data](#persistent-data)
* [Getting Help](#getting-help)

## Contribution Guidelines

Go read [our contribution guidelines](https://github.com/sonatype/docker-nexus3/blob/master/.github/CONTRIBUTING.md) to get a bit more familiar with how
we would like things to flow.

## Running

To run, binding the exposed port 8081 to the host.

```
$ docker run -d -p 8081:8081 --name nexus sonatype/nexus3
```

To test:

```
$ curl -u admin:admin123 http://localhost:8081/service/metrics/ping
```

## Building the Nexus Repository Manager image

To build a docker image from the Docker file you can use this command:

```
$ docker build --rm=true --tag=sonatype/nexus3 .
```

The following optional variables can be used when building the image:

- NEXUS_VERSION: Version of the Nexus Repository Manager
- NEXUS_DOWNLOAD_URL: Download URL for Nexus Repository, alternative to using `NEXUS_VERSION` to download from Sonatype
- NEXUS_DOWNLOAD_SHA256_HASH: Sha256 checksum for the downloaded Nexus Repository Manager archive. Required if `NEXUS_VERSION`
 or `NEXUS_DOWNLOAD_URL` is provided

## Chef Solo for Runtime and Application

Chef Solo is used to build out the runtime and application layers of the Docker image. The Chef cookbook being used is available
on GitHub at [sonatype/chef-nexus-repository-manager](https://github.com/sonatype/chef-nexus-repository-manager).

## Testing the Dockerfile

We are using `rspec` as the test framework. `serverspec` provides a docker backend (see the method `set` in the test code)
 to run the tests inside the docker container, and abstracts away the difference between distributions in the tests
 (e.g. yum, apt,...).

    rspec [--backtrace] spec/Dockerfile_spec.rb

## Red Hat Certified Image

A Red Hat certified container image can be created using `Dockerfile.rh.el` which is built to be compliant with Red Hat certification.
The image includes additional meta data to comform with Kubernetes and OpenShift standards, a directory with the
licenses applicable to the software and a man file for help on how to use the software. It also uses an ENTRYPOINT
script the ensure the running user has access to the appropriate permissions for OpenShift 'restricted' SCC. In addition to the
Red Hat Enterprise Linux image, `Dockerfile.rh.centos` provides the same additions but with a CentOS base.

The Red Hat certified container image is available from the 
[Red Hat Container Catalog](https://access.redhat.com/containers/#/registry.connect.redhat.com/sonatype/nexus-repository-manager)
and qualified accounts can pull it from registry.connect.redhat.com.

## Notes

* Default credentials are: `admin` / `admin123`

* It can take some time (2-3 minutes) for the service to launch in a
new container.  You can tail the log to determine once Nexus is ready:

```
$ docker logs -f nexus
```

* Installation of Nexus is to `/opt/sonatype/nexus`.  

* A persistent directory, `/nexus-data`, is used for configuration,
logs, and storage. This directory needs to be writable by the Nexus
process, which runs as UID 200.

* There is an environment variable that is being used to pass JVM arguments to the startup script

  * `INSTALL4J_ADD_VM_PARAMS`, passed to the Install4J startup script. Defaults to `-Xms1200m -Xmx1200m -XX:MaxDirectMemorySize=2g -Djava.util.prefs.userRoot=${NEXUS_DATA}/javaprefs`.

  This can be adjusted at runtime:

  ```
  $ docker run -d -p 8081:8081 --name nexus -e INSTALL4J_ADD_VM_PARAMS="-Xms2g -Xmx2g -XX:MaxDirectMemorySize=3g  -Djava.util.prefs.userRoot=/some-other-dir" sonatype/nexus3
  ```

  Of particular note, `-Djava.util.prefs.userRoot=/some-other-dir` can be set to a persistent path, which will maintain
  the installed Nexus Repository License if the container is restarted.

* Another environment variable can be used to control the Nexus Context Path

  * `NEXUS_CONTEXT`, defaults to /

  This can be supplied at runtime:

  ```
  $ docker run -d -p 8081:8081 --name nexus -e NEXUS_CONTEXT=nexus sonatype/nexus3
  ```

### Persistent Data

There are two general approaches to handling persistent storage requirements
with Docker. See [Managing Data in Containers](https://docs.docker.com/engine/tutorials/dockervolumes/)
for additional information.

  1. *Use a docker volume*.  Since docker volumes are persistent, a volume can be created specifically for
  this purpose.  This is the recommended approach.  

  ```
  $ docker volume create --name nexus-data
  $ docker run -d -p 8081:8081 --name nexus -v nexus-data:/nexus-data sonatype/nexus3
  ```

  2. *Mount a host directory as the volume*.  This is not portable, as it
  relies on the directory existing with correct permissions on the host.
  However it can be useful in certain situations where this volume needs
  to be assigned to certain specific underlying storage.  

  ```
  $ mkdir /some/dir/nexus-data && chown -R 200 /some/dir/nexus-data
  $ docker run -d -p 8081:8081 --name nexus -v /some/dir/nexus-data:/nexus-data sonatype/nexus3
  ```

## Getting Help

Looking to contribute to our Docker image but need some help? There's a few ways to get information or our attention:

* Chat with us on [Gitter](https://gitter.im/sonatype/nexus-developers)
* File an issue [on our public JIRA](https://issues.sonatype.org/projects/NEXUS/)
* Check out the [Nexus3](http://stackoverflow.com/questions/tagged/nexus3) tag on Stack Overflow
* Check out the [Nexus Repository User List](https://groups.google.com/a/glists.sonatype.com/forum/?hl=en#!forum/nexus-users)
