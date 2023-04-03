#!/bin/bash

CONN_PER_SEC=$1
DURATION_MIN=$2
TIMEOUT_MS=$3

if [ -z "$1" -o -z "$2" -o -z "$3" ]; then
    echo "Usage: sh $0 <CONN_PER_SEC> <DURATION_MIN> <TIMEOUT_MS>"
    echo "Example:"
    echo " sh $0 30 5 2000"
    echo " sh $0 30 10 5000"
    exit 1
fi

DURATION_SEC=$(( ${DURATION_MIN} * 60 ))

# Get resource information
export LAMBDA_ARN=$( aws cloudformation describe-stacks --stack-name FisStackLoadGen --query "Stacks[*].Outputs[?OutputKey=='LoadGenArn'].OutputValue" --output text )
export URL_HOME=$( aws cloudformation describe-stacks --stack-name FisStackAsg --query "Stacks[*].Outputs[?OutputKey=='FisAsgUrl'].OutputValue" --output text )
export URL_PHP=${URL_HOME}/phpinfo.php
export URL_PI=${URL_HOME}/pi.php

#echo LAMBDA_ARN=$LAMBDA_ARN
#echo URL_HOME=$URL_HOME
#echo URL_PHP=$URL_PHP

# Workaround for AWS CLI v1/v2 compatibility issues
export CLI_MAJOR_VERSION=$( aws --version | grep '^aws-cli' | cut -d/ -f2 | cut -d. -f1 )
if [ "$CLI_MAJOR_VERSION" == "2" ]; then FIX_CLI_PARAM="--cli-binary-format raw-in-base64-out"; else unset FIX_CLI_PARAM; fi

aws lambda invoke \
  --function-name ${LAMBDA_ARN} \
  --payload "{
        \"ConnectionTargetUrl\": \"${URL_PI}\", 
        \"ExperimentDurationSeconds\": ${DURATION_SEC},
        \"ConnectionsPerSecond\": ${CONN_PER_SEC},
        \"ReportingMilliseconds\": 1000,
        \"ConnectionTimeoutMilliseconds\": ${TIMEOUT_MS},
        \"TlsTimeoutMilliseconds\": ${TIMEOUT_MS},
        \"TotalTimeoutMilliseconds\": ${TIMEOUT_MS}
    }" \
  $FIX_CLI_PARAM \
  --invocation-type Event \
  /dev/null

echo "Run load for ${DURATION_MIN} mins"