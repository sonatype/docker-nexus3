#!/bin/sh
#
# Copyright:: Copyright (c) 2017-present Sonatype, Inc. Apache License, Version 2.0.
#
# arbitrary uid recognition at runtime - for OpenShift deployments
sed "s@${USER_NAME}:x:${USER_UID}:@${USER_NAME}:x:\${USER_ID}:@g" /etc/passwd > /etc/passwd.template
