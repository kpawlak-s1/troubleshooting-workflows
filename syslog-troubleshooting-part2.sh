# get container id of the scalyr agent container
docker_scalyr_id=$(docker ps | grep scalyr-agent-docker-json | awk '{print $1}')

docker exec -it $docker_scalyr_id /bin/bash