#!/usr/bin/env bash

set -x
set -eo pipefail

if [ "$1" == 'bin/nexus' ]; then
	mkdir -p "$NEXUS_DATA"
	chown -R nexus "$NEXUS_DATA"
	exec gosu nexus "$@"
fi

exec "$@"
