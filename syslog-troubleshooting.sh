#!/bin/bash


# Get the output of 'docker -v'
docker_version_output=$(docker -v)

# Check if the output contains the word 'build'. if it is not found then docker is not isntalled
if [[ $docker_version_output == *"build"* ]]; then
   echo "docker is installed"
else
    echo "docker does not appear to be installed. please install it."
    exit 1
fi

# Get the output of 'docker compose version' to see if docker compose is installed

docker_compose_version_output=$(docker compose version)
# Check if the output contains the word 'build'. if it is not found then docker is not isntalled
if [[ $docker_version_output == *"v"* ]]; then
   echo "docker compose is installed"
else
    echo "docker compose does not appear to be installed. please install it."
    exit 1
fi

#get output of an ls to look for syslog.yaml
syslog_yaml_output=$(ls | grep syslog.yaml)

#check if syslog.yaml file exists

if [[ $syslog_yaml_output == *"syslog.yaml"* ]]; then
   echo "syslog.yaml file exists"
else
    echo "you need to create the syslog.yaml file"
    exit 1
fi

#verify if syslog.crt exists
syslog_crt_output=$(ls | grep syslog.crt)

if [[ $syslog_crt_output == *"syslog.crt"* ]]; then
   echo "syslog.crt file exists"
else
    echo "you need to create the syslog cert file. attempting this for you now"
    openssl req -x509 -nodes -newkey rsa:4096 -keyout syslog.key -out syslog.crt -subj '/CN=<host>' -days 3650

    #verify if syslog.crt exists now
syslog_crt_output=$(ls | grep syslog.crt)

if [[ $syslog_crt_output == *"syslog.crt"* ]]; then
   echo "syslog.crt file successfully created"
else
    echo "syslog.crt file still does not  exist, please try again manually"
    exit 1
fi
fi



#verify if syslog.key exists
syslog_key_output=$(ls | grep syslog.key)

if [[ $syslog_key_output == *"syslog.key"* ]]; then
   echo "syslog.key file exists"
else
    echo "you need to create the syslog.key file. for some reason the prior commands did not create it. please try manually"
    exit 1
fi

#verify if docker-compose.yml exists
docker_compose_yml_output=$(ls | grep docker-compose.yml)

if [[ $docker_compose_yml_output == *"docker-compose.yml"* ]]; then
   echo "docker-compose.yml file exists"
else
    echo "you need to create the docker-compose.yml file. attempting this for you now"
    curl -o docker-compose.yml https://app.scalyr.com/scalyr-repo/stable/latest/syslog-collector/docker-compose-latest.yml   
    docker_compose_yml_output=$(ls | grep docker-compose.yml)

    if [[ $docker_compose_yml_output == *"docker-compose.yml"* ]]; then
   echo "docker-compose.yml file successfully created"
    else
    echo "failed to created docker-compose.yml file. please try manually"
    exit 1  
    fi
fi


#get status of each expected docker container
docker_scalyr_output=$(docker ps | grep scalyr-agent-docker-json)
docker_syslog_output=$(docker ps | grep syslog-collector-syslog)
docker_config_gen_output=$(docker ps | grep syslog-collector-config-generator)

echo " "
echo "in a moment, we will check the status of the expected containers. if they are not up, we will start them. If this fails you will get some info."
echo "if this is successful, you will see docker start and the prompt you have open will no longer be available to run commands in"
echo "hitting control-c or similar to exit closes the containers"
echo "if this happens, you should check if you are now getting the expected logs in S1"
echo "if you are not, then please open a new command prompt and we will run part two of the troubleshooting workflow"
echo "this is available here: https://github.com/kpawlak-s1/troubleshooting-workflows/blob/main/syslog-troubleshooting-part2.sh"

read -p "Do you want to advance to the next step? Type 'yes' to continue: " user_input

# Check if the input is exactly 'yes'
if [[ "$user_input" == "yes" ]]; then
    echo "Proceeding to the next step..."
else
    echo "Exiting script. Approval not given."
    exit 1  # Exit with error code 1
fi


#check status of scalyr agent container. if it is not up, tear down all containers and rerun docker compose. If it is still not up, point user towards logs
if [[ $docker_scalyr_output == *"scalyr-agent-docker-json"* ]]; then
   echo "scalyr agent container is running"
else
    echo "scalyr agent container not running in this directory. attempting to restart the containers"
    docker compose down
    docker compose up
    docker_scalyr_output=$(docker ps | grep scalyr-agent-docker-json)
    if [[ $docker_scalyr_output == *"scalyr-agent-docker-json"* ]]; then
    echo "docker scalyr agent container is now running"
    else
        echo "failed to start the scalyr agent docker container. Please use 'sudo docker-compose logs | grep scalyr_agent' to inspect the docker logs to find out why "
        exit 1
    fi
fi


#check status of syslog container. if it is not up, tear down all containers and rerun docker compose. If it is still not up, point user towards logs
if [[ $docker_syslog_output == *"syslog-collector-syslog"* ]]; then
   echo "syslog-collector-syslog container is running"
else
    echo "syslog-collector-syslog agent container not running in this directory. attempting to restart the containers"
    docker compose down
    docker compose up
    docker_syslog_output=$(docker ps | grep syslog-collector-syslog)
    if [[ $docker_syslog_output == *"syslog-collector-syslog"* ]]; then
    echo "docker syslog-collector-syslog agent container is now running"
    else
        echo "failed to start the syslog-collector-syslog agent docker container. Please use 'sudo docker-compose logs | grep syslog-collector-syslog' to inspect the docker logs to find out why "
        exit 1
    fi
fi



#check status of config gen container. if it is not up, tear down all containers and rerun docker compose. If it is still not up, point user towards logs
if [[ $docker_config_gen_output == *"syslog-collector-config-generator"* ]]; then
   echo "syslog-collector-config-generator container is running"
else
    echo "syslog-collector-config-generator container not running in this directory. attempting to restart the containers"
    docker compose down
    docker compose up
    docker_config_gen_output=$(docker ps | grep syslog-collector-config-generator)
    if [[ $docker_config_gen_output == *"syslog-collector-config-generator"* ]]; then
    echo "docker syslog-collector-config-generator container is now running"
    else
        echo "failed to start the syslog-collector-config-generatort docker container. Please use 'sudo docker-compose logs | grep syslog-collector-config-generator' to inspect the docker logs to find out why "
        exit 1
    fi
fi



