join-swarm() {
    local name=$1
    shift
    local token=$1
    shift
    local leader=$1
    echo "> $name joining the swarm"
    docker-machine ssh ${name} \
                   "docker swarm join --token ${token} \
                        --listen-addr $(docker-machine ip $name) \
                        --advertise-addr $(docker-machine ip $name) \
                        ${leader}"
}

ips() {
    docker-machine ip $(docker-machine ls -q)
}

machines() {
    docker-machine ls --format 'table {{.Name}} {{.DriverName}} {{.URL}}'
}

visualizer() {
    docker-machine ssh $1 \
              "docker service create \
	      -p 8080:8080 \
              --name visualizer \
              --constraint=node.role==manager \
              --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
              manomarks/visualizer"

}
