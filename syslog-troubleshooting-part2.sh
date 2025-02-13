# get container id of the scalyr agent container
docker_scalyr_id=$(docker ps | grep scalyr-agent-docker-json | awk '{print $1}')

#request the file parsing  status of the agent.json file in the scalyr docker container
docker exec "$docker_scalyr_id" scalyr-agent-2 status -v | grep 'Good (files parsed successfully)' >> ./agent-json-parsing-status.txt
sudo chmod 777 ./agent-json-parsing-status.txt

parsing_check=$(cat agent-json-parsing-status.txt)

echo "$parsing_check" >> parse_check.txt

# Check if "test" exists in the text
if  echo "$parsing_check" | grep -q "Good" ; then
    echo "scalyr agent config successfully parsed"
else
    echo "scalyr agent config file not successfully parsed. please open /etc/scalyr-agent-2/agent.json and inspect for potential issues"
    exit 1
fi

#delete the temp files created above
rm ./agent-json-parsing-status.txt
rm ./parse_check.txt

#extract list of worker files from the contaioner
docker exec "$docker_scalyr_id" find /var/log/scalyr-agent-2 -type f -name '*worker*' >> file-list.txt

#set the file variable
file="file-list.txt"

#loop through all agent worker log files to look for log entries indicating a bad parameter
while IFS= read -r line; do
    docker exec "$docker_scalyr_id" cat $line | grep 'blocking' >> ./badParamresults.txt
done < "$file"

#check if the resulting file (merged multiple possible worker files) contains the badParam error

if ! grep -q "$search_string" "$file"; then
    echo "no badParam errors"
else
    echo "badParam errors found. Most likely your API key or URL are incorrect. please check your syslog.yaml file and verify"
fi

#clean up files from this stage
rm ./file-list.txt
rm ./badParamresults.txt