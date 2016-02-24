#!/usr/bin/env bash

INSTANCE_IDS=""
for INSTANCE_ID in `aws ec2 describe-instances --output table --filters Name=tag:Owner,Values=TelkomselFMS | grep InstanceId | sed 's/.*\(i-[0-9a-z]*\) *.*/\1/'`
do
  INSTANCE_IDS="${INSTANCE_IDS} ${INSTANCE_ID}"
done
INSTANCE_IDS=`echo $INSTANCE_IDS | sed 's/^ //'`
aws ec2 stop-instances --instance-ids $INSTANCE_IDS

exit 0

