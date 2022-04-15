import boto3
from botocore.config import Config
import os
import logging

alb_arn = os.environ.get('ALB_ARN')
alb_name = os.environ.get('ALB_NAME')
aws_region = os.environ.get('AWS_REGION')
vpc_id = os.environ.get('VPC_ID')

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

elb_client = boto3.client('elbv2', config=my_config)

# create new Target Group with IpAddressType = ipv6
# https://github.com/hashicorp/terraform-provider-aws/issues/23386

logger.info(f'Creating TG for ALB: {alb_name}')
create_tg = elb_client.create_target_group(
    Name=alb_name,
    Protocol='HTTP',
    Port=80,
    VpcId=vpc_id,
    TargetType='ip',
    IpAddressType='ipv6'
)