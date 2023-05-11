# Demo on Chaos Engineering

Original source repo came from [AWS chaos engineering workshop](https://chaos-engineering.workshop.aws/).

## Preparation Steps

1. Create environment in Cloud9. Choose **t3.small**.

2. Change the EBS root volume size to **30GB gp3**.

3. Extend file system size:
   
   ```shell
   sudo growpart /dev/nvme0n1 1
   sudo xfs_growfs -d /
   ```

4. Open Cloud9 IDE.

5. Run command to clone repository and provision AWS resources. (ref: [Workshop Studio](https://catalog.us-east-1.prod.workshops.aws/workshops/5fc0039f-9f15-47f8-aff0-09dc7b1779ee/en-US/020-starting-workshop/020-self-paced/050-create-stack))
   
   ```shell
   cd ~/environment
   #git clone https://github.com/aws-samples/aws-fault-injection-simulator-workshop.gitcd aws-fault-injection-simulator-workshop
   git clone https://github.com/khchan123/aws-fault-injection-simulator-workshop.git
   cd aws-fault-injection-simulator-workshop
   cd resources/templates
   #./deploy-parallel.sh
   ./deploy-reinvent2022-dop313.sh
   ```

6. Create FIS service role **FisWorkshopServiceRole**. (reference: [Workshop Studio](https://catalog.us-east-1.prod.workshops.aws/workshops/5fc0039f-9f15-47f8-aff0-09dc7b1779ee/en-US/030-basic-content/030-basic-experiment/10-permissions))
   
   But first create IAM policy **FisWorkshopServicePolicy**.
   
   ```json
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Sid": "AllowFISExperimentLoggingActionsCloudwatch",
               "Effect": "Allow",
               "Action": [
                   "logs:CreateLogDelivery",
                   "logs:PutResourcePolicy",
                   "logs:DescribeResourcePolicies",
                   "logs:DescribeLogGroups"
               ],
               "Resource": "*"
           },
           {
               "Sid": "AllowFISExperimentRoleReadOnly",
               "Effect": "Allow",
               "Action": [
                   "ec2:DescribeInstances",
                   "ecs:DescribeClusters",
                   "ecs:ListContainerInstances",
                   "eks:DescribeNodegroup",
                   "iam:ListRoles",
                   "rds:DescribeDBInstances",
                   "rds:DescribeDbClusters",
                   "ssm:ListCommands"
               ],
               "Resource": "*"
           },
           {
               "Sid": "AllowFISExperimentRoleEC2Actions",
               "Effect": "Allow",
               "Action": [
                   "ec2:RebootInstances",
                   "ec2:StopInstances",
                   "ec2:StartInstances",
                   "ec2:TerminateInstances"
               ],
               "Resource": "arn:aws:ec2:*:*:instance/*"
           },
           {
               "Sid": "AllowFISExperimentRoleECSActions",
               "Effect": "Allow",
               "Action": [
                   "ecs:UpdateContainerInstancesState",
                   "ecs:ListContainerInstances"
               ],
               "Resource": "arn:aws:ecs:*:*:container-instance/*"
           },
           {
               "Sid": "AllowFISExperimentRoleEKSActions",
               "Effect": "Allow",
               "Action": [
                   "ec2:TerminateInstances"
               ],
               "Resource": "arn:aws:ec2:*:*:instance/*"
           },
           {
               "Sid": "AllowFISExperimentRoleFISActions",
               "Effect": "Allow",
               "Action": [
                   "fis:InjectApiInternalError",
                   "fis:InjectApiThrottleError",
                   "fis:InjectApiUnavailableError"
               ],
               "Resource": "arn:*:fis:*:*:experiment/*"
           },
           {
               "Sid": "AllowFISExperimentRoleRDSReboot",
               "Effect": "Allow",
               "Action": [
                   "rds:RebootDBInstance"
               ],
               "Resource": "arn:aws:rds:*:*:db:*"
           },
           {
               "Sid": "AllowFISExperimentRoleRDSFailOver",
               "Effect": "Allow",
               "Action": [
                   "rds:FailoverDBCluster"
               ],
               "Resource": "arn:aws:rds:*:*:cluster:*"
           },
           {
               "Sid": "AllowFISExperimentRoleSSMSendCommand",
               "Effect": "Allow",
               "Action": [
                   "ssm:SendCommand"
               ],
               "Resource": [
                   "arn:aws:ec2:*:*:instance/*",
                   "arn:aws:ssm:*:*:document/*"
               ]
           },
           {
               "Sid": "AllowFISExperimentRoleSSMCancelCommand",
               "Effect": "Allow",
               "Action": [
                   "ssm:CancelCommand"
               ],
               "Resource": "*"
           }
       ]
   }
   ```
   Then create IAM role **FisWorkshopServiceRole**. Select trusted entity **AWS account**, **This account**. Attach and AWS managed policy start with **AWSFaultInjectionSimulator** and the policy **FisWorkshopServicePolicy** just created. After the IAM role **FisWorkshopServiceRole**, edit the trust policy as follow:
   ```json
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Principal": {
                   "Service": [
                   "fis.amazonaws.com"
                   ]
               },
               "Action": "sts:AssumeRole",
               "Condition": {}
           }
       ]
   }
   ```


7. Create IAM role for SSM. (reference: [Workshop Studio](https://catalog.us-east-1.prod.workshops.aws/workshops/5fc0039f-9f15-47f8-aff0-09dc7b1779ee/en-US/030_basic_content/040_ssm/050_direct_automation#create-ssm-document))
   
   Method 1: (Not working if you are running in Cloud9) Run the following commands or do it in AWS console.
   
   ```shell
   cd ~/environment/aws-fult-injection-simulator-workshop
   cd workshop/content/030_basic_content/040_ssm/050_direct_automation
   
   ROLE_NAME=FisWorkshopSsmEc2DemoRole
   
   aws iam create-role \
     --role-name ${ROLE_NAME} \
     --assume-role-policy-document file://iam-ec2-demo-trust.json
   
   aws iam put-role-policy \
     --role-name ${ROLE_NAME} \
     --policy-name ${ROLE_NAME} \
     --policy-document file://iam-ec2-demo-policy.json
   ```
   
   Method 2: Create IAM role **FisWorkshopSsmEc2DemoRole** in AWS console for AWS servicei **System Manager**. Then create inline policy **EnableAsgDocument** for the IAM role just created.
   
   ```json
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Sid": "EnableAsgDocument",
               "Effect": "Allow",
               "Action": [
                   "autoscaling:DescribeAutoScalingGroups",
                   "autoscaling:SuspendProcesses",
                   "autoscaling:ResumeProcesses",
                   "ec2:DescribeInstances",
                   "ec2:DescribeInstanceStatus",
                   "ec2:TerminateInstances"
               ],
               "Resource": "*"
           }
       ]
   }
   ```
   
   Create another inline policy **EnableAZSimlulation** for the IAM role.
   
   ```json
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Sid": "EnableAsgDocument",
               "Effect": "Allow",
               "Action": [
                   "autoscaling:DescribeAutoScalingGroups",
                   "autoscaling:SuspendProcesses",
                   "autoscaling:ResumeProcesses",
                   "autoscaling:UpdateAutoScalingGroup",
                   "ec2:DescribeInstances",
                   "ec2:DescribeInstanceStatus",
                   "ec2:TerminateInstance",
                   "ec2:DescribeSubnets"
               ],
               "Resource": "*"
           }
       ]
   }
   ```

8. Modify IAM policy **FisWorkshopServicePolicy**. Add the following lines to the policy statement. Replace XXXXXXXXXX with your AWS account ID.
   
   ```json
           {
               "Sid": "EnableSSMAutomationExecution",
               "Effect": "Allow",
               "Action": [
                   "ssm:GetAutomationExecution",
                   "ssm:StartAutomationExecution",
                   "ssm:StopAutomationExecution"
               ],
               "Resource": "*"
           },
           {
               "Sid": "AllowFisToPassListedRolesToSsm",
               "Effect": "Allow",
               "Action": [
                   "iam:PassRole"
               ],
               "Resource": "arn:aws:iam::XXXXXXXXXX:role/FisWorkshopSsmEc2DemoRole"
           },
   ```

9. Create SSM documents.
   
   ```shell
   cd ~/environment/aws-fault-injection-simulator-workshop
   cd workshop/content/030_basic_content/040_ssm/050_direct_automation
   
   SSM_DOCUMENT_NAME=TerminateAsgInstances
   
   # Create SSM document
   
   aws ssm create-document \
     --name ${SSM_DOCUMENT_NAME} \
     --document-format YAML \
     --document-type Automation \
     --content file://ssm-terminate-instances-asg-az.yaml
   
   # Construct ARN
   
   REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
   ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')
   DOCUMENT_ARN=arn:aws:ssm:${REGION}:${ACCOUNT_ID}:document/${SSM_DOCUMENT_NAME}
   echo $DOCUMENT_ARN
   ```
   
   ```shell
   cd ~/environment/aws-fault-injection-simulator-workshop
   cd workshop/content/030_basic_content/040_ssm/050_direct_automation
   
   SSM_DOCUMENT_NAME=RemoveAZfromASG
   
   # Create SSM document
   
   aws ssm create-document \
     --name ${SSM_DOCUMENT_NAME} \
     --document-format YAML \
     --document-type Automation \
     --content file://ssm-asg-remove-az.yaml
   
   # Construct ARN
   
   REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
   ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')
   DOCUMENT_ARN=arn:aws:ssm:${REGION}:${ACCOUNT_ID}:document/${SSM_DOCUMENT_NAME}
   echo $DOCUMENT_ARN
   ```

10. Create FIS experiment templates.
    
    ```shell
    cd ~/environment/aws-fault-injection-simulator-workshop
    cd resources/code/scripts/
    . cheat-03.sh
    . cheat-09.sh
    . cheat-10.sh
    . cheat-11.sh
    # import into FIS experiment template if you see "Parameter validation failed" (aws cli v1 not compatible)
    ```

## Useful commands

### Environment variables
```shell
# Export the variables into environments
export LAMBDA_ARN=$( aws cloudformation describe-stacks --stack-name FisStackLoadGen --query "Stacks[*].Outputs[?OutputKey=='LoadGenArn'].OutputValue" --output text )
export URL_HOME=$( aws cloudformation describe-stacks --stack-name FisStackAsg --query "Stacks[*].Outputs[?OutputKey=='FisAsgUrl'].OutputValue" --output text )
export URL_PHP=${URL_HOME}/phpinfo.php
export URL_PI=${URL_HOME}/pi.php

# Or source the cheat script
source ~/environment/aws-fault-injection-simulator-workshop/resources/code/scripts/cheat-01.sh
```

### Handy script to run load
```shell
cd ~/environment/aws-fault-injection-simulator-workshop
cd resources/code/scripts/
sh run_load_pi_14m.sh
```

### Run static page load for 3min: generate 1000 connections per second for 3 minutes
```shell
aws lambda invoke \
  --function-name ${LAMBDA_ARN} \
  --payload "{
        \"ConnectionTargetUrl\": \"${URL_HOME}\",
        \"ExperimentDurationSeconds\": 180,
        \"ConnectionsPerSecond\": 1000,
        \"ReportingMilliseconds\": 1000,
        \"ConnectionTimeoutMilliseconds\": 2000,
        \"TlsTimeoutMilliseconds\": 2000,
        \"TotalTimeoutMilliseconds\": 2000
    }" \
  $FIX_CLI_PARAM \
  --invocation-type Event \
  /dev/null
```

### Run php load for 5min: generate 1000 connections per second
```shell
aws lambda invoke \
  --function-name ${LAMBDA_ARN} \
  --payload "{
        \"ConnectionTargetUrl\": \"${URL_PHP}\", 
        \"ExperimentDurationSeconds\": 300,
        \"ConnectionsPerSecond\": 1000,
        \"ReportingMilliseconds\": 1000,
        \"ConnectionTimeoutMilliseconds\": 2000,
        \"TlsTimeoutMilliseconds\": 2000,
        \"TotalTimeoutMilliseconds\": 2000
    }" \
  $FIX_CLI_PARAM \
  --invocation-type Event \
  /dev/null 
```

### Run php load for 5min, 3x in parallel because max per lambda is 1000
```shell
for ii in 1 2 3; do
  aws lambda invoke \
    --function-name ${LAMBDA_ARN} \
    --payload "{
          \"ConnectionTargetUrl\": \"${URL_PHP}\",
          \"ExperimentDurationSeconds\": 300,
          \"ConnectionsPerSecond\": 1000,
          \"ReportingMilliseconds\": 1000,
          \"ConnectionTimeoutMilliseconds\": 2000,
          \"TlsTimeoutMilliseconds\": 2000,
          \"TotalTimeoutMilliseconds\": 2000
      }" \
    $FIX_CLI_PARAM \
    --invocation-type Event \
    /dev/null
done
```
### Run infrequent cpu load for 5min, generate 10 connections per second
```shell
aws lambda invoke \
  --function-name ${LAMBDA_ARN} \
  --payload "{
        \"ConnectionTargetUrl\": \"${URL_PI}\",
        \"ExperimentDurationSeconds\": 300,
        \"ConnectionsPerSecond\": 10,
        \"ReportingMilliseconds\": 1000,
        \"ConnectionTimeoutMilliseconds\": 2000,
        \"TlsTimeoutMilliseconds\": 2000,
        \"TotalTimeoutMilliseconds\": 2000
    }" \
  $FIX_CLI_PARAM \
  --invocation-type Event \
  /dev/null
```