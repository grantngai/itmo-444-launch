#!/bin/bash
./cleanup.sh

declare -a instanceARR

mapfile -t instanceARR < <(aws ec2 run-instances --image-id $1 --count $2 --instance-type $3 --key-name $6 --security-group-ids $4 --subnet-id $5 --associate-public-ip-address --iam-instance-profile Name=$7 --user-data file://../itmo-444-env/install-webserver.sh --out table | grep InstanceId | sed "s/|//g" | tr -d ' ' | sed "s/InstanceId//g")
echo ${instanceARR[@]}

aws ec2 wait instance-running --instance-ids ${instanceARR[@]}

ELBURL=(`aws elb create-load-balancer --load-balancer-name itmo444pngai-lb --listeners Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80 --security-groups $4 --subnets $5 --output=text`)
