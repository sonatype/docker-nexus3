#!/bin/sh
#
# Copyright (c) 2016-present Sonatype, Inc. All rights reserved.
# Includes the third-party code listed at http://links.sonatype.com/products/nxrm/attributions.
# "Sonatype" is a trademark of Sonatype, Inc.
#

# arbitrary uid recognition at runtime - for OpenShift deployments
sed "s@${USER_NAME}:x:${USER_UID}:@${USER_NAME}:x:\${USER_ID}:@g" /etc/passwd > /etc/passwd.template
