import boto3
import logging
import os
from botocore.config import Config
from botocore.exceptions import ClientError

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

# alb_name = os.environ.get('ALB_NAME')
alb_name = "ipv6-test"
aws_region = os.environ.get('AWS_REGION')

my_config = Config(
    region_name=aws_region,
    signature_version='v4',
    retries={
        'max_attempts': 10,
        'mode': 'adaptive'
    }
)

elb_client = boto3.client('elbv2', config=my_config)

# remove previously created ALB listener and Target Group

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
