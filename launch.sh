#!/bin/bash
./cleanup.sh

declare -a instanceARR

mapfile -t instanceARR < <(aws ec2 run-instances --image-id $1 --count $2 --instance-type $3 --key-name $6 --security-group-ids $4 --subnet-id $5 --associate-public-ip-address --iam-instance-profile Name=$7 --user-data file://../itmo-444-env/install-webserver.sh --out table | grep InstanceId | sed "s/|//g" | tr -d ' ' | sed "s/InstanceId//g")
echo ${instanceARR[@]}

aws ec2 wait instance-running --instance-ids ${instanceARR[@]}

ELBURL=(`aws elb create-load-balancer --load-balancer-name itmo444pngai-lb --listeners Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80 --security-groups $4 --subnets $5 --output=text`)
echo $ELBURL

echo -e "\nFinished launching ELB and sleeping 60 seconds"
for i in {0..60}; do echo -ne '.'; sleep 1;done

aws elb register-instances-with-load-balancer --load-balancer-name itmo444pngai-lb --instances ${instanceARR[@]}

aws elb configure-health-check --load-balancer-name itmo444pngai-lb --health-check Target=HTTP:80/index.html,Interval=30,UnhealthyThreshold=2,HealthyThreshold=2,Timeout=3

echo -3 "\nWaiting an additional 60 seconds - before opening the ELB in a webbrowser"
for i in {0..60}; do echo -ne '.'; sleep 1;done

aws autoscaling create-launch-configuration --launch-configuration-name itmo444-launch-config --image-id $1 --key-name $6 --security-groups $4 --instance-type $3 --user-data file://../itmo-444-env/install-webserver.sh --iam-instance-profile $7

aws autoscaling create-auto-scaling-group --auto-scaling-group-name itmo444-extended-auto-scaling-group-2 --launch-configuration-name itmo444-launch-config --load-balancer-names itmo444pngai-lb --health-check-type ELB --min-size 3 --max-size 6 --desired-capacity 3 --default-cooldown 600 --health-check-grace-period 120 --vpc-zone-identifier $5

mapfile -t dbinstanceARR < <(aws rds describe-db-instances --output json | grep "\"DBInstanceIdentifier" | sed "s/[\"\:\, ]//g" | sed "s/DBInstanceIdentifier//g")

aws rds create-db-instance --db-name pngaidb --db-instance-identifier pngai --db-instance-class db.t1.micro --engine MySQL --master-username controller --master-user-password Pingvin5 --allocated-storage 5 --db-subnet-group-name default --publicly-accessible
