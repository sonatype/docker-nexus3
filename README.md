<!--

    Copyright (c) 2016-present Sonatype, Inc. All rights reserved.
    Includes the third-party code listed at http://links.sonatype.com/products/nxrm/attributions.
    "Sonatype" is a trademark of Sonatype, Inc.

-->
<!-- 
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
# Sonatype Nexus Repository

Sonatype Nexus Repository is the single source of truth for all your internal and third-party binaries, components, and packages. Integrate all your development tools into a centralized binary repository manager so that you can choose the best open source components, optimize your build performance, and ship code quickly while increasing visibility across your SDLC.

### Announcing Nexus Repository Community Edition  
As of version 3.77.0, the free edition of Nexus Repository is now called **Sonatype Nexus Repository Community Edition**.

Community Edition is designed to deliver robust repository management for individual users and small teams. Upgrading to 3.77.0 unlocks powerful new features, including access to previously Pro-only formats, seamless integration with containerized environments like Kubernetes, and more. Community Edition does also include some usage limitations. To learn more, [see the Community Edition documentation](https://help.sonatype.com/en/ce-onboarding.html).


* [Contribution Guidlines](#contribution-guidelines)
* [Running](#running)
* [Building the Sonatype Nexus Repository image](#building-the-nexus-repository-manager-image)
* [Chef Solo for Runtime and Application](#chef-solo-for-runtime-and-application)
* [Testing the Dockerfile](#testing-the-dockerfile)
* [Red Hat Certified Image](#red-hat-certified-image)
* [Notes](#notes)
  * [Persistent Data](#persistent-data)
* [Getting Help](#getting-help)

## Contribution Guidelines

Go read [our contribution guidelines](https://github.com/sonatype/docker-nexus3/blob/main/.github/CONTRIBUTING.md) to get a bit more familiar with how
we would like things to flow.

## Running

To run, binding the exposed port 8081 to the host, use:

```
$ docker run -d -p 8081:8081 --name nexus sonatype/nexus3
```

When stopping, be sure to allow sufficient time for the databases to fully shut down.  

```
docker stop --time=120 <CONTAINER_NAME>
```


To test:

```
$ curl http://localhost:8081/
```

## Building the Sonatype Nexus Repository image

To build a docker image from the [Dockerfile](https://github.com/sonatype/docker-nexus3/blob/main/Dockerfile) you can use this command:

```
$ docker build --rm=true --tag=sonatype/nexus3 .
```

The following optional variables can be used when building the image:

- NEXUS_VERSION: Version of the Sonatype Nexus Repository
- NEXUS_DOWNLOAD_URL: Download URL for Sonatype Nexus Repository, alternative to using `NEXUS_VERSION` to download from Sonatype
- NEXUS_DOWNLOAD_SHA256_HASH: Sha256 checksum for the downloaded Sonatype Nexus Repository archive. Required if `NEXUS_VERSION`
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

A Red Hat certified container image can be created using [Dockerfile.rh.ubi](https://github.com/sonatype/docker-nexus3/blob/main/Dockerfile.rh.ubi) which is built to be compliant with Red Hat certification.
The image includes additional meta data to comform with Kubernetes and OpenShift standards, a directory with the
licenses applicable to the software and a man file for help on how to use the software. It also uses an ENTRYPOINT
script the ensure the running user has access to the appropriate permissions for OpenShift 'restricted' SCC. 

The Red Hat certified container image is available from the 
[Red Hat Container Catalog](https://access.redhat.com/containers/#/registry.connect.redhat.com/sonatype/nexus-repository-manager)
and qualified accounts can pull it from registry.connect.redhat.com.

## Other Red Hat Images

In addition to the Universal Base Image, we can build images based on:
* Red Hat Enterprise Linux: [Dockerfile.rh.el](https://github.com/sonatype/docker-nexus3/blob/main/Dockerfile.rh.el)
* CentOS: [Dockerfile.rh.centos](https://github.com/sonatype/docker-nexus3/blob/main/Dockerfile.rh.centos)

## Alpine Image

An Alpine-based container image can be created using [Dockerfile.alpine.java11](https://github.com/sonatype/docker-nexus3/blob/main/Dockerfile.alpine.java11) This Dockerfile is built to leverage the minimalistic and efficient nature of Alpine Linux, emphasizing fewer dependencies to achieve a cleaner SBOM (Software Bill of Materials) and a stronger security posture.

The Alpine-based container image includes minimal dependencies and uses an ENTRYPOINT script to ensure the application runs with the necessary permissions. It is optimized for rapid deployment and efficient resource usage.

The Alpine-based container image is available from Docker Hub and can be pulled using the following tags:

- sonatype/nexus3:3.XX.y-alpine (runs Java 11)
- sonatype/nexus3:3.XX.y-java11-alpine
- sonatype/nexus3:3.XX.y-java17-alpine

## Notes

* Our [system requirements](https://help.sonatype.com/display/NXRM3/System+Requirements) should be taken into account when provisioning the Docker container.
* Default user is `admin` and the uniquely generated password can be found in the `admin.password` file inside the volume. See [Persistent Data](#user-content-persistent-data) for information about the volume.

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

  * `INSTALL4J_ADD_VM_PARAMS`, passed to the Install4J startup script. Defaults to `-Xms2703m -Xmx2703m -XX:MaxDirectMemorySize=2703m -Djava.util.prefs.userRoot=${NEXUS_DATA}/javaprefs`.

  This can be adjusted at runtime:

  ```
  $ docker run -d -p 8081:8081 --name nexus -e INSTALL4J_ADD_VM_PARAMS="-Xms2703m -Xmx2703m -XX:MaxDirectMemorySize=2703m -Djava.util.prefs.userRoot=/some-other-dir" sonatype/nexus3
  ```

  Of particular note, `-Djava.util.prefs.userRoot=/some-other-dir` can be set to a persistent path, which will maintain
  the installed Sonatype Nexus Repository License if the container is restarted.
  
  Be sure to check the [memory requirements](https://help.sonatype.com/display/NXRM3/System+Requirements#SystemRequirements-MemoryRequirements) when deciding how much heap and direct memory to allocate.

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

## Getting In Touch
If you are using Nexus Repository Core or Community Edition and need to report an issue or request an enhancement, [open an issue here](https://github.com/sonatype/nexus-public/issues).

For help with Nexus Repository Core or Community Edition, please join the [Sonatype Community](https://community.sonatype.com/) to get tips and tricks from other users.

To report a security vulnerability, please see https://www.sonatype.com/report-a-security-vulnerability

Sonatype Nexus Repository Pro customers can contact our world-class support team at https://support.sonatype.com/.

## License Disclaimer

_Sonatype Nexus Repository Core is distributed with Sencha Ext JS pursuant to a FLOSS Exception agreed upon between Sonatype, Inc. and Sencha Inc. Sencha Ext JS is licensed under GPL v3 and cannot be redistributed as part of a closed source work._

_All use of and access to Sonatype Nexus Repository Community Edition is governed by [these terms and conditions](https://www.sonatype.com/dnt/usage/community-edition-eula)._

_Copyright © 2008-present Sonatype, Inc._
