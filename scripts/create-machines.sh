#!/usr/bin/env bash
# Setup a cluster
set -e

test -z "$DO_TOKEN" && {
    echo "You need to set DO_TOKEN"
    exit 1
}

MANAGERS=3
WORKERS=5
MANAGER_PREFIX=vdedemo-manager
WORKER_PREFIX=vdedemo-worker
LEADER=${MANAGER_PREFIX}1

create-machine() {
    local name=$1
    shift
    echo ">> create node ${name} with args: ${args}"
    docker-machine create \
                   --driver=digitalocean \
                   --digitalocean-access-token=$DO_TOKEN \
                   --digitalocean-region=ams2 \
                   --digitalocean-image=debian-8-x64 \
		   --engine-opt "experimental" \
		   $@ \
                   ${name}
}

echo "> Create manager"
for node in $(seq 1 $MANAGERS); do
    create-machine ${MANAGER_PREFIX}${node}
    sleep 5
done

echo "> Create workers"
for node in $(seq 1 $WORKERS); do
    n=$(($node%2))
    ARGS="--engine-label group=group${n}"
    if test $n -eq 1; then
	ARGS="${ARGS} --engine-label disk=ssd"
    fi
    echo $ARGS
    create-machine ${WORKER_PREFIX}${node} ${ARGS}
    sleep 5
done
