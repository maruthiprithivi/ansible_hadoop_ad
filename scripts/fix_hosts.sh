#!/usr/bin/env bash

DOMAIN='cdh.hadoop'
OWNER=SteveJohansen

INSTANCE_IDS=""
for INSTANCE_ID in `aws ec2 describe-instances --output table --filters Name=tag:Owner,Values=${OWNER} | grep InstanceId | sed 's/.*\(i-[0-9a-z]*\) *.*/\1/'`
do
  HOST=`aws ec2 describe-instances --instance-ids=$INSTANCE_ID --output table | grep '||||  Name' | egrep -v running | awk -F'|' '{print $6}' | sed 's/ *//' | sed 's/ *$//'`
  NEW_IP=`aws ec2 describe-instances --output table --filters Name=tag:Name,Values=${HOST} | grep PublicIpAddress | awk -F'|' '{print $5}' | sed 's/ *//' | sed 's/ *$//'`
  echo $INSTANCE_ID $HOST $NEW_IP
  grep -q "$HOST.$DOMAIN" /etc/hosts
  if [ "$?" -eq "1" ]
  then
    printf "$NEW_IP    $HOST.$DOMAIN\n" | sudo tee -a /etc/hosts
  else
    sudo sed -i -e "s/^.*$HOST.$DOMAIN/$NEW_IP    $HOST.$DOMAIN/" \
      /etc/hosts
  fi
done

exit 0

