#!/usr/bin/env bash
# Setup a cluster
set -e

test -z "$DO_TOKEN" && {
    echo "You need to set DO_TOKEN"
    exit 1
}

MANAGERS=3
WORKERS=3
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

join-swarm() {
    local name=$1
    shift
    local token=$1
    echo "> $name joining the swarm"
    docker-machine ssh ${name} \
                   "docker swarm join \
                        --token ${token} \
                        --listen-addr $(docker-machine ip $name) \
                        --advertise-addr $(docker-machine ip $name) \
                        ${LEADER_IP}"
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

LEADER_IP=$(docker-machine ip ${LEADER})

echo "> initialize cluster (on ${LEADER})"
docker-machine ssh ${LEADER} \
               "docker swarm init --listen-addr ${LEADER_IP} --advertise-addr ${LEADER_IP}"

export manager_token=$(docker-machine ssh ${LEADER} "docker swarm join-token manager -q")
export worker_token=$(docker-machine ssh ${LEADER} "docker swarm join-token worker -q")

echo "manager token: ${manager_token}"
echo "worker token:  ${worker_token}"

for node in $(seq 2 $MANAGERS); do
    join-swarm ${MANAGER_PREFIX}${node} ${manager_token}
done

for node in $(seq 1 $WORKERS); do
    join-swarm ${WORKER_PREFIX}${node} ${worker_token}
done

echo "> List nodes in the swarm"
docker-machine ssh ${LEADER} docker node ls

echo "> Install docker-compose on ${LEADER}"
docker-machine ssh ${LEADER} "curl -L https://github.com/docker/compose/releases/download/1.11.0-rc1/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose"

echo "> Get demo repo on ${LEADER}"
docker-machine ssh ${LEADER} "git clone https://github.com/vdemeester/orchestration-kit-snowcamp-2017.git"

echo "> Execute some pre-steps"
docker-machine ssh ${LEADER} \
	       "cd orchestration-kit-snowcamp-2017/stacks && \
	       docker stack deploy --compose-file registry.yml registry && \
	       docker-compose -f tools.yml build && \
	       docker-compose -f tools.yml push && \
	       docker-compose -f dockercoins.yml build && \
	       docker-compose -f dockercoins.yml push"
