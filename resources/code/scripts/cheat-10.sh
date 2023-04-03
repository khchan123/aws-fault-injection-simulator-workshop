#!/bin/bash

echo "Create FIS template for Demo"

# Set required variables
export DEMO_TEMPLATE_NAME=RemoveAZfromASG

export DEMO_SSM_DOCUMENT_NAME=RemoveAZfromASG
export DEMO_SSM_DOCUMENT_ARN=arn:aws:ssm:${REGION}:${ACCOUNT_ID}:document/${DEMO_SSM_DOCUMENT_NAME}
export REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')

export DEMO_ASG_NAME=$( aws cloudformation describe-stack-resources --stack-name FisStackAsg --query "StackResources[?ResourceType=='AWS::AutoScaling::AutoScalingGroup'].PhysicalResourceId" --output text  )
export DEMO_AZ_OPTIONS=$( aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ${DEMO_ASG_NAME} --query "AutoScalingGroups[*].AvailabilityZones" --output text )
export DEMO_AZ_NAME=$( aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ${DEMO_ASG_NAME} --query "AutoScalingGroups[*].AvailabilityZones[0]" --output text )

export FIS_ROLE_NAME=FisWorkshopServiceRole
export SSM_ROLE_NAME=FisWorkshopSsmEc2DemoRole

export FIS_ROLE_ARN=arn:aws:iam::${ACCOUNT_ID}:role/${FIS_ROLE_NAME}
export SSM_ROLE_ARN=arn:aws:iam::${ACCOUNT_ID}:role/${SSM_ROLE_NAME}

EXISTS=$( aws fis list-experiment-templates --query "experimentTemplates[?tags.Name=='${DEMO_TEMPLATE_NAME}'].id" --output text )

if [ -z "$EXISTS" ]; then

    cat cheat-10/template.json | envsubst > /tmp/cheat-10.json

    aws fis create-experiment-template \
    --cli-input-json file:///tmp/cheat-10.json
    if [ $? -ne 0 ]; then
        cat /tmp/cheat-10.json
    fi
else
    echo "Template exists with ID ${EXISTS}"
fi
