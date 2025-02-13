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
    docker exec "$docker_scalyr_id" cat $line | grep 'badParam' >> ./badParamresults.txt
done < "$file"

#check if the resulting file (merged multiple possible worker files) contains the badParam error

if ! grep -q "badParam" "./badParamresults.txt"; then
    echo "no badParam errors"
else
    echo "badParam errors found. Most likely your API key is not valid as it is malformed (missing characters, etc)"
fi

#loop through all agent worker log files to look for log entries indicating a bad URL
while IFS= read -r line; do
    docker exec "$docker_scalyr_id" cat $line | grep 'Name or service not known' >> ./badURL.txt
done < "$file"

#check if the resulting file (merged multiple possible worker files) contains the Name or service not known error

if ! grep -q "Name or service not known" "./badURL.txt"; then
    echo "no badParam errors"
else
    echo "Name or service not known errors found. Most likely your URL is incorrect. please check your syslog.yaml file and verify"
fi


#loop through all agent worker log files to look for log entries indicating a bad API key (but properly formatted)
while IFS= read -r line; do
    docker exec "$docker_scalyr_id" cat $line | grep 'invalid write logs api key' >> ./badAPI.txt
done < "$file"

#check if the resulting file (merged multiple possible worker files) contains the Name or service not known error

if ! grep -q "invalid write logs api key" "./badAPI.txt"; then
    echo "no invalid write logs api key errors"
else
    echo "invalid write logs api key errors found. Most likely your API key is incorrect, although it has a valid format. please check your syslog.yaml file and verify"
fi



#clean up files from this stage
rm ./file-list.txt
rm ./badParamresults.txt
rm ./badAPI.txt

echo " "
echo "ok, let's check network connectivity from the this host to the S1 cloud"

#use curl to check connection
curl -k --connect-timeout 5 https://xdr.us1.sentinelone.net >> ./curl-result.txt

#check the results of the curl
if ! grep -q "SCALYR" "./curl-result.txt"; then
    echo "curl connection failed"
    curl=fail
else
    echo "curl connection successful"
fi

rm ./curl-result.txt


if curl=fail; then
    echo "lets  check DNS"
    nslookup xdr.us1.sentinelone.net
    echo "compare this IP to the list of possible IPs from our documentation: https://community.sentinelone.com/s/article/000004961."
    echo "this requires logging in so you will have to do so in your browser"
    echo " "
    read -p "Did you find this IP on that page? yes or no:   " user_input

    if [[ "$user_input" == "yes" ]]; then
    echo "DNS seems to be working properly"
    else
    echo "Sounds like a DNS issue. I recommend you look into your DNS settings"
    exit 1  # Exit with error code 1
    fi
else

echo "as the curl worked, we can conclude that there are no outbound connectivity issues. your agent should be sending logs to S1"
echo "you may just not be getting syslog. to go verify you are getting logs from the agent you can search based on the serverHost value equaling the scalyr agent container id"
echo "in your case this would be opening up the data lake and searching 'serverHost = $docker_scalyr_id' "
echo "you should find logs there"
fi

echo "ok, let's test if syslog reception is working on your syslog docker container"

file="syslog.yaml"

# Extract the value after "matcher: " following "destport"
destport_matcher=$(grep -A1 "destport" "$file" | tail -n1 | awk -F"matcher: " '{print $2}')

# Extract the value after "matcher: " following "proto"
proto_matcher=$(grep -A1 "proto" "$file" | tail -n1 | awk -F"matcher: " '{print $2}')

# Output results
echo "Destport Matcher: $destport_matcher"
echo "Proto Matcher: $proto_matcher"

echo "ok, now that we have the details, let's try actually sending some data"
echo " "

if [[ $proto_matcher == *"tcp"* ]]; then
echo "trying tcp port $destport_matcher"
echo "<1>$(date '+%b %d %H:%M:%S') localhost test[$((RANDOM % 100))]: hello world via tcp" | nc -N -v 127.0.0.1 $destport_matcher  > syslog-replay-result.txt

else
echo "trying udp port $destport_matcher"
echo "<1>$(date '+%b %d %H:%M:%S') localhost test[$((RANDOM % 100))]: hello world via udp" | nc -N -v -u 127.0.0.1 $destport_matcher > syslog-replay-result.txt
fi

echo "search 'hello world' in your data lake tenant. if you find matches this syslog message was sent successfully to S1 Cloud"

read -p "did you find a match? yes/no:   " syslog_success

#check the results of the syslog replay
if [[ "$syslog_success" == "yes" ]]; then
     rm ./syslog-replay-result.txt
     echo "excellent...."
     echo " "
    
else

    echo "restart the syslog docker container. heck restart them all. do 'docker compose down' followed by 'docker compose up' "
    echo "if that doesn't work, then might be time to open a support ticket and ask for help, because the conatiners are running, syslog just is not receiving"
    rm ./syslog-replay-result.txt
    exit 1
fi

echo "___________________________________________________________"
echo "at this point we know that"
echo "1. your agent is collected to the s1 cloud and sending logs"
echo "2. that sending syslog locally from this host to the syslog collection container works and the logs make it to the s1 cloud"
echo " "
echo "so we have narrowed down the issue to being the delivery of the logs via the syslog protocol to this host"
echo " "

echo "as we don't have control over your network, this is the limit of what I can automate for you"
echo "however we can provide some ideas of what to check for"
echo " " 
echo "1. on this host, check if the OS firewall could be blocking incoming traffic on $proto_matcher/$destport_matcher"
echo " you could also use tcp dump or a similar packet sniffing tech to verify if this host is seeing traffic coming in on said port and protocol"
echo " "

echo "if you don't see anything, but host firewall doesn't seem to be the issue, then it could be..."
echo "a network firewall"
echo "a general network issue (like no route from your syslog source to this host)"
echo "an issue with your syslog source (it is not sending to the right port/proto) or (its host firewall is blocking the traffic) or (it is having dns problens if your using the FQDN of this host)"
echo "good ways to test would be going to any intermediary network devices / firewalls and checking logs there to see if traffic is being sent"
echo "you could also set up a test linux box and move it around your network to test the ability to send syslog messages across your network to this host"
echo " "
echo "that would look like sending the following command"

echo "echo \"<1>$(date '+%b %d %H:%M:%S') routerEdge test[$((RANDOM % 100))]: Test message from another linux host to syslog server\" | nc -N -v x.x.x.x $destport_matcher"
echo "this example command is for tcp. add the -u flag to the nc command for udp"

echo " "
echo "thanks for making use of this script"
echo "____________________________________________"
