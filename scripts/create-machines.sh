#!/usr/bin/env bash
# Setup a cluster
set -e

test -z "$DO_TOKEN" && {
    echo "You need to set DO_TOKEN"
    # exit 1
}

MACHINES=6
MACHINES_PREFIX=vdedemo

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
for node in $(seq 1 $MACHINES); do
    create-machine ${MACHINES_PREFIX}${node}
    sleep 5
done

docker-machine scp ./docker-compose.yml ${MACHINES_PREFIX}1:~/
