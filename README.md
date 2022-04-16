# Minority report: the state of IPv6 on AWS
## Is it ready to solve your IPv4 exhaustion or overlaps problems?
Well, it depends on whether you use managed container orchestration services like ECS/EKS or not. Also, it's not that easy to use if your IaC tool of choice is Terraform.
## The problem
For some unbelievable reason (we're cloud-native, right?) you might end up without any free IP in your subnets. Or you can't assign any additional CIDRs to the VPC. Or you must stop using overlapping pools and assign new sets of addresses to all existing AWS resources. You're good to go if all your infrastructure is immutable, but still, some VPC-based resources like RDS, Amazon MQ, or ElastiCache are not so easy to move. Why not just use IPv6? It was designed to address exactly such a problem and we had dozen years to develop (cloud)infrastructure and (cloud)services to adopt it[13], right?
## Familiar stuff
We're all aware that the IPv6 pool can be assigned to AWS VPC and subnets since people were throwing rocks at dinosaurs. Some of us know that both ALB  and NLB can be deployed in dual-stack mode. At the end of 2021 IPv6-only subnets and EC2 instances were added[1] to that mix. That gives us a seamless possibility to provide an ingress path from the IPv4 world to the IPv6. It is also clear that IPv6-only resources can talk to other IPv6 resources.
## Not-so-familiar stuff
What if such a resource needs to communicate with an IPv4-only resource like RDS or some integration endpoint? That is where "IPv6 Addressing of IPv4/IPv6 Translators" comes in handy. RFC 6052 [4] defines how it works, and it's pretty old (2010). I didn't know such a mechanism exist till I read the "Let Your IPv6-only Workloads Connect to IPv4 Services"[3] article on the AWS news blog by Sébastien Stormacq (thanks!). In AWS it was implemented as **NAT64** and **DNS64** where 64 stands for six to four, not 64-bits :-) First, it was available only in the US regions[5] and lately made available in all regions[6].

The connection process is as follows:
* DNS query is sent to DNS64.
* If no AAAA record is available then the IPv4 address from the A record is being encoded and the well-known IPv6 prefix **64:ff9b::/96** is added.
* Connection is being routed to the NAT64 gateway because of the route table entry containing a well-known IPv6 prefix. It works similarly to the IPv4 NAT, but instead of using ports for connection mapping between two networks it uses hexadecimal/decimal conversion and prepends prefix.
## What extra configuration is required?
Few things:
* If we already have VPC with IPv6 block assigned we need to create an IPv6-native subnet with DNS64 enabled.
* In the public IPv4 subnet we need ordinary NAT GW (there is no NAT64 option to enable). If we need to access resources only inside VPC this NAT GW can be set to "Private" connectivity type[7] (without Elastic IP assigned).
* Route table associated with the IPv6-native subnet should contain **64:ff9b::/96** entry pointing to the NAT GW.
## Testing with EC2 instances and RDS
All works as expected. In this example, I've checked if the connection to the ssh port of the IPv4 instance will work. To allow translation on DNS64 we must use the instance DNS name, not the IP address:
```
$ host ip-10-254-1-235.ec2.internal
ip-10-254-1-235.ec2.internal has address 10.254.1.235 <- existing A record
ip-10-254-1-235.ec2.internal has IPv6 address 64:ff9b::afe:1eb <-- AAAA record synthesized by DNS64

$ ssh ip-10-254-1-235.ec2.internal
Last login: Fri Apr 15 16:29:27 2022 from ip-10-254-1-53.ec2.internal
    __|  __|_  )
    _|  (     /   Amazon Linux 2 AMI
    ___|\___|___|  
https://aws.amazon.com/amazon-linux-2/
[ec2-user@i-0665cf03d19422d2f ~]$
```
EC2 instance IP **10.254.1.235** was translated to **afe:1eb** as follows:
```
a = 10
fe = 254
1 = 1
eb = 235
```
The same thing happens while accessing the RDS database:
```
$ host database-1.crgkq0caj7yx.us-east-1.rds.amazonaws.com
database-1.crgkq0caj7yx.us-east-1.rds.amazonaws.com has address 10.254.1.222 <- existing A record
database-1.crgkq0caj7yx.us-east-1.rds.amazonaws.com has IPv6 address 64:ff9b::afe:1de <-- AAAA record synthesized by DNS64

$ telnet database-1.crgkq0caj7yx.us-east-1.rds.amazonaws.com 5432
Trying 64:ff9b::afe:1de...
Connected to database-1.crgkq0caj7yx.us-east-1.rds.amazonaws.com.
Escape character is '^]'.
```
RDS instance IP **10.254.1.222** was translated to **afe:1de** where **de** (hex) = **222** (dec).
It's not possible to create a DB subnet group consisting only IPv6-native subnets.
## OK, but what about containers?
In short: it can't be done. I've tried ECS with both EC2 and Fargate launch types. Despite that, the ECS agent can connect to the cluster the ECS service with IPv6-native subnet specified in the **awsvpcConfiguration** won't be created. The same goes for the Fargate:
```
$ aws ecs create-service - cluster mikosins-test - service-name mikosins-cli - task-definition mikosins-test:7 - desired-count 1 - launch-type FARGATE - network-configuration "awsvpcConfiguration={subnets=[subnet-0e97f73c45963fffd],securityGroups=[sg-0a163307d2b3c6576]}"

An error occurred (ServerException) when calling the CreateService operation (reached max retries: 2): Service Unavailable. Please try again later.
```
I knew about the **dualStackIPv6** account-level ECS setting[10] and enabled it beforehand.
```
$ aws ecs put-account-setting --name dualStackIPv6 --value enabled
```
## Let's try EKS!
IP family set to IPv6. Can't create a cluster in IPv6-native subnets:
```
Error: error creating EKS Cluster (mikosins-test): InvalidParameterException: Provided subnets subnet-00eda6293a334280e Free IPs: 0 subnet-0c5d7830239eef2c5 Free IPs: 0 , need at least 5 IPs in each subnet to be free for this operation
```
the same for the Fargate Profile:
```
Subnet subnet-00eda6293a334280e needs both an IPv4 and IPv6 CIDR to use Fargate with IPv6 cluster
```
and the same for the Node Group:
```
Error: error creating EKS Node Group (mikosins-test:mikosins-test):
InvalidParameterException: Not enough available IPs across subnets
```
> Amazon EKS does not support dual-stack clusters. However, if your worker nodes contain an IPv4 address, EKS will configure IPv6 pod routing so that pods can communicate with cluster external IPv4 endpoints.

That means that to communicate with IPv4 endpoints the NAT on the instance itself is used and there is no need for DNS64 and NAT64[17].
## Final tips
* To make yum work on IPv6-only instance with AMZN2[11] use **amazon-linux-https disable** command or add it to the user data in LT if you need ASGs.
* To make IMDS work enable IPv6 protocol in metadata options (currently only aws_launch_template supports this[8]).
* Creating a TG with **IpAddressType** parameter set to IPv6 is currently not possible using Terraform[9] and AWS CLI. It is only possible using the AWS console or the API (I've used boto3 for that matter).
* VPC endpoints do not support IPv6-native subnets. But if you put them in the dual-stack subnets with the "Enable DNS name" option checked then it works using the translation mechanism.
* To download images from Docker Hub on IPv6-only hosts you must use a dedicated endpoint (beta support)[12]. Requests rate limiting is in place same as for IPv4.
* If you're running EC2s only or self-managed container orchestration solutions make sure to check out the "Dual Stack and IPv6-only Amazon VPC Reference Architectures"[14].
## TF code
Terraform with supporting Python code used as the playground is available here[15].
## References
1. https://aws.amazon.com/blogs/networking-and-content-delivery/introducing-ipv6-only-subnets-and-ec2-instances/
2. https://aws.amazon.com/blogs/networking-and-content-delivery/dual-stack-ipv6-architectures-for-aws-and-hybrid-networks/
3. https://aws.amazon.com/blogs/aws/let-your-ipv6-only-workloads-connect-to-ipv4-services/
4. https://datatracker.ietf.org/doc/html/rfc6052
5. https://aws.amazon.com/about-aws/whats-new/2021/11/aws-nat64-dns64-communication-ipv6-ipv4-services/
6. https://aws.amazon.com/about-aws/whats-new/2022/02/aws-expands-nat64-dns64-regions/
7. https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html
8. https://github.com/hashicorp/terraform-provider-aws/issues/22332
9. https://github.com/hashicorp/terraform-provider-aws/issues/23386
10. https://docs.aws.amazon.com/AmazonECS/latest/userguide/ecs-account-settings.html
11. https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/install-updates.html
12. https://www.docker.com/blog/beta-ipv6-support-on-docker-hub-registry/
13. https://www.google.com/intl/en/ipv6/statistics.html#tab=per-country-ipv6-adoption
14. https://d1.awsstatic.com/architecture-diagrams/ArchitectureDiagrams/IPv6-reference-architectures-for-AWS-and-hybrid-networks-ra.pdf
15. https://github.com/michal-kosinski/aws-ipv6-to-ipv4-translation
16. https://aws.amazon.com/blogs/containers/amazon-eks-launches-ipv6-support/
17. https://docs.aws.amazon.com/eks/latest/userguide/cni-ipv6.html
18. https://aws.amazon.com/about-aws/whats-new/2022/01/amazon-eks-ipv6/
19. https://aws.amazon.com/blogs/aws/amazon-elastic-kubernetes-service-adds-ipv6-networking/
## Links
@medium.com:

@linkedin: 