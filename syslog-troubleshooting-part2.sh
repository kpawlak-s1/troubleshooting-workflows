# get container id of the scalyr agent container
docker_scalyr_id=$(docker ps | grep scalyr-agent-docker-json | awk '{print $1}')

#request the file parsing  status of the agent.json file in the scalyr docker container
docker exec "$docker_scalyr_id" scalyr-agent-2 status -v | grep 'Good (files parsed successfully)' >> agent-json-parsing-status.txt

parsing_check = cat ./agent-json-parsing-status-txt | grep 'Good' 

# Check if "test" exists in the text
if [[ $parsing_check == *"Good"* ]]; then
    echo "scalyr agent config successfully parsed"
else
    echo "scalyr agent config file not successfully parsed. please open /etc/scalyr-agent-2/agent.json and inspect for potential issues"
    exit 1
fi

