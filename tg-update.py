import boto3
from botocore.config import Config
import os
import logging

asg_name = os.environ.get('ASG_NANE')
aws_region = os.environ.get('AWS_REGION')
tg_arn = os.environ.get('TG_ARN')

my_config = Config(
    region_name=aws_region,
    signature_version='v4',
    retries={
        'max_attempts': 10,
        'mode': 'adaptive'
    }
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

asg_client = boto3.client('autoscaling', config=my_config)
ec2_client = boto3.client('ec2', config=my_config)
elb_client = boto3.client('elbv2', config=my_config)

# get instance ids from the AutoScaling Group
logger.info(f'Trying to describe ASG: {asg_name}')
describe_asgs = asg_client.describe_auto_scaling_groups(AutoScalingGroupNames=[asg_name])

instance_ids = []
for asg in describe_asgs['AutoScalingGroups']:
    for instance in asg['Instances']:
        instance_ids.append(instance['InstanceId'])
    logger.info(f'Instance IDs: {instance_ids}')

# register IPv6-only instances created by the AutoScaling group to the Target Group
for instances in ec2_client.describe_instances(Filters=[{'Name': 'instance-state-name', 'Values': ["running"]}],
                                               InstanceIds=instance_ids)['Reservations']:
    for ip in instances['Instances']:
        ip_address = ip['Ipv6Address']
        logger.info(f'Registering IP {ip_address} to TG {tg_arn}')
        elb_response = elb_client.register_targets(
            TargetGroupArn=tg_arn,
            Targets=[
                {
                    'Id': ip_address,
                    'Port': 80
                },
            ]
        )
