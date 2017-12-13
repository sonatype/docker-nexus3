% NEXUS(1) Container Image Pages
% Sonatype
% November 21, 2016

# NAME
nexus \- Nexus Repository Manager container image

# DESCRIPTION
The nexus image provides a containerized packaging of the Nexus Repository Manager.
Nexus Repository Manager is a repository manager with universal support for popular component formats including Maven, Docker, NuGet, npm, PyPi, Bower and more.

The nexus image is designed to be run by the atomic command with one of these options:

`run`

Starts the installed container with selected privileges to the host.

`stop`

Stops the installed container

The container itself consists of:
    - Linux base image
    - Oracle Java JDK
    - Nexus Repository Manager
    - Atomic help file

Files added to the container during docker build include: /help.1.

# USAGE
To use the nexus container, you can run the atomic command with run, stop, or uninstall options:

To run the nexus container:

  atomic run nexus

To stop the nexus container (after it is installed), run:

  atomic stop nexus

# LABELS
The nexus container includes the following LABEL settings:

That atomic command runs the docker command set in this label:

`RUN=`

  LABEL RUN='docker run -d -p 8081:8081 --name ${NAME} ${IMAGE}'

  The contents of the RUN label tells an `atomic run nexus` command to open port 8081 & set the name of the container.

`STOP=`

  LABEL STOP='docker stop ${NAME}'

`Name=`

The registry location and name of the image. For example, Name="Nexus Repository Manager".

`Version=`

The Nexus Repository Manager version from which the container was built. For example, Version="3.0.2-02".

When the atomic command runs the nexus container, it reads the command line associated with the selected option
from a LABEL set within the Docker container itself. It then runs that command. The following sections detail
each option and associated LABEL:

# SECURITY IMPLICATIONS

`-d`

Runs continuously as a daemon process in the background
