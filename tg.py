import boto3
import logging
import os
import sys
from botocore.config import Config
from botocore.exceptions import ClientError

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

alb_arn = os.environ.get('ALB_ARN')
alb_name = os.environ.get('ALB_NAME')
asg_name = os.environ.get('ASG_NANE')
aws_region = os.environ.get('AWS_REGION')
tg_arn = os.environ.get('TG_ARN')
vpc_id = os.environ.get('VPC_ID')

my_config = Config(
    region_name=aws_region,
    signature_version='v4',
    retries={
        'max_attempts': 10,
        'mode': 'adaptive'
    }
)

asg_client = boto3.client('autoscaling', config=my_config)
ec2_client = boto3.client('ec2', config=my_config)
elb_client = boto3.client('elbv2', config=my_config)


def create():
    logger.info(f'Creating TG for ALB: {alb_name}')
    create_tg = elb_client.create_target_group(
        Name=alb_name,
        Protocol='HTTP',
        Port=80,
        VpcId=vpc_id,
        TargetType='ip',
        IpAddressType='ipv6'
    )


def update():
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


def destroy():
    try:
        logger.info(f'Trying to list TG for ALB: {alb_name}')
        for tg in elb_client.describe_target_groups(Names=[alb_name])['TargetGroups']:
            tg_arn = tg['TargetGroupArn']
            logger.info(f'Trying to delete TG: {tg_arn}')
            delete_tg = elb_client.delete_target_group(
                TargetGroupArn=tg_arn
            )
    except ClientError as error:
        if error.response['Error']['Code'] == 'TargetGroupNotFound':
            logger.warning('TG not found')
        else:
            logger.warning(f'Unexpected error: {error}')
        raise error


if __name__ == '__main__':
    if len(sys.argv) > 1:
        if sys.argv[1] == "create":
            create()
        elif sys.argv[1] == "update":
            update()
        elif sys.argv[1] == "destroy":
            destroy()
    else:
        logger.error(f'Usage: {sys.argv[0]} create | update | destroy')
