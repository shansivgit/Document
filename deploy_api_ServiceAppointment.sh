#!/usr/bin/env bash

#Stop on error
set -e;

print_usage() {
  (>&2 echo "Usage: $0 -a <<account>> -e <<environment>> -v <<version>> [-r <<aws-region>>] [-p <<aws-profile>>]");
  (>&2 echo "Example: $0 -a wowinc-dev-otr -e dev -v V1 -r us-east-1 -p default");
  exit 1;
};

# #Set environment variable
get_opts() {
	while getopts ":a:e:v:r:f:p:" opt; do
	  case $opt in
	    a) export account="$OPTARG";
	    ;;
	    e) export environment="$OPTARG";
	    ;;
	    v) export version="$OPTARG";
	    ;;
	    r) export aws_deploy_region="$OPTARG";
	    ;;
			p) export aws_cred_profile="$OPTARG";
			;;
	    \?) echo "Invalid option -$OPTARG" >&2;
	    exit 1;
	    ;;
	  esac;
	done;

	[[ -z "${account// }" ]] && print_usage;
	[[ -z "${environment// }" ]] && print_usage;
	[[ -z "${version// }" ]] && print_usage;

	# aws_deploy_region is not checked because it is set a default value below
	# aws_cred_profile is not checked because it is set a default value below

	return 0;
};

#Set basedir
basedir=$(dirname "$0");
cfn_templates="$basedir/cfn-templates";
get_opts $@;

# if profile name was not set, use 'default'
aws_profile=${aws_cred_profile:-"default"};
# if region was not set, use 'us-east-1'
aws_region=${aws_deploy_region:-"us-east-1"};
# this is used to define the profile arguments in the CLI calls.
# if it is set to the "default", then it will be empty.
# this allows the "internal" credential order to go in to play... environment variables, default profile, etc.
profile_argument="--profile $aws_profile";

# If the profile name is this, then do not pass a profile
if [[ $aws_profile == "default" ]]; then
	profile_argument="";
fi

echo "============================================";
echo "Begin $0 with arguments:";
echo -e "\taccount: ${account}";
echo -e "\tenvironment: ${environment}";
echo -e "\tversion: ${version}";
echo -e "\tprofile: ${aws_profile}";
echo -e "\tregion: ${aws_region}";
echo "============================================";

# Set code repository backet
if [[ "$aws_deploy_region" -eq "us-east-1" ]]; then
	code_repository="$account-wowapi-code-repository";
else
	code_repository="$account-wowapi-code-repository-${aws_deploy_region}";
fi

# Set service name
service_name='ServiceAppointment';
# the file name that is created by the grunt task below. example: `serviceaddress_latest.zip`
service_zip=$(echo $service_name | awk '{print tolower($0) "_latest.zip"}');

# Set APIendpoint title and host
if [ $environment == "prod" ]; then
  title=$service_name$version;
  host="api.wowinc.com";
else
  title=$service_name$version'_'$environment;
  host=$environment".api.wowinc.com";
fi

# Delete local service properties if any
rm -rf "$basedir/service.properties";

echo "============================================";
echo "Retrieve latest service.properties";
echo "============================================";

# Get enviroment properties from S3 bucket
aws s3 cp "s3://$code_repository/$environment/$service_name/config/service.properties" "$basedir/service.properties" --region $aws_region $profile_argument;

# Source the service properties
. "$basedir/service.properties";

# Delete local service properties if any
rm -rf "$basedir/service.properties";

# Set stack names
security_stack_name="wowapi-$environment-$service_name-sec";
api_stack_name="wowapi-$environment-$service_name";

echo "============================================";
echo "Prepare NodeJS code package";
echo "============================================";

# Prepare Nodejs code
grunt lambda_package:$service_name;
rm -rf $basedir/../dist/code;

echo "============================================";
echo "Expand $service_zip";
echo "============================================";

unzip $basedir/../dist/$service_zip -d $basedir/../dist/code;

echo "============================================";
echo "Start deploy of stack: $security_stack_name";
echo "============================================";

# TODO: These should all be passed as parameters in the cloudformation template
sed -e "s/\${codeRepository}/$code_repository/" -e "s/\${SubnetId1}/$SubnetId1/" -e "s/\${SubnetId2}/$SubnetId2/" -e "s/\${SecurityGroupId}/$SecurityGroupId/" "$basedir/$service_name-sec-cf-template.yaml" > "$basedir/$service_name-sec-cf.yaml";

# Deploy api security stack
bash "$basedir/aws_cloudformation.sh" deploy --template-file "$cfn_templates/$service_name-Authorizer.yaml" \
  --stack-name $security_stack_name --capabilities CAPABILITY_IAM --parameter-overrides PGUser="$PGUser" \
  PGDatabase="$PGDatabase" PGPassword="$PGPassword" PGHost="$PGHost" PGPort="$PGPort" PGTimeout="$PGTimeout" \
  PGMaxClients="$PGMaxClients" KMSKey="$EnvVariablesKmsKeyId" CodeRepository="$code_repository" \
  SubnetId1="$SubnetId1" SubnetId2="$SubnetId2" SecurityGroupId="$SecurityGroupId" \
  --region $aws_region $profile_argument;

echo "============================================";
echo "Retrieve AuthorizerFunctionArn";
echo "============================================";

# Get authorizer function arn
authorizerFunctionArn=$(aws cloudformation describe-stacks --stack-name $security_stack_name --query 'Stacks[0].Outputs[?OutputKey==`AuthorizerFunctionArn`].OutputValue' --output text --region $aws_region $profile_argument);


echo "============================================";
echo "Retrieved AuthorizerFunctionArn: $authorizerFunctionArn";
echo "============================================";

echo "============================================";
echo "Get account id";
echo "============================================";

accountId=$(aws sts get-caller-identity --output text --query 'Account' --region $aws_region $profile_argument);

echo "============================================";
echo "AccountId: ${accountId}";
echo "============================================";

# Delete previous swagger file
rm -rf "$basedir/$service_name-swagger.yaml";

# Substitute authorizer function ARN, title and host placeholders in the template swagger file
sed -e "s/\${Wow\.ApiTitle}/$title/" -e "s/\${Wow\.ApiHost}/$host/" -e "s/\${Wow.ApiVersion}/$version/" \
  -e "s/\${Wow\.AuthorizerFunctionArn}/$authorizerFunctionArn/" -e "s/\${Wow\.AccountId}/$accountId/" \
  -e "s/\${Wow\.Environment}/$environment/" "$cfn_templates/$service_name-swagger-template.yaml" \
  > "$cfn_templates/$service_name-swagger.yaml";

echo "============================================";
echo "Package up $service_name-cf.yaml";
echo "============================================";

# Package the code
aws cloudformation package --template-file "$cfn_templates/$service_name.yaml" --output-template-file "$basedir/$service_name-cf.yaml" --s3-bucket "$code_repository" --s3-prefix "$environment/$service_name" --kms-key-id="$S3KmsKeyId" --region $aws_region $profile_argument;

echo "============================================";
echo "Start deploy of stack: $api_stack_name";
echo "============================================";

# Deploy api stack
bash "$basedir/aws_cloudformation.sh" deploy --template-file "$basedir/$service_name.yaml" \
	--stack-name $api_stack_name --capabilities CAPABILITY_IAM --parameter-overrides \
	SecurityStackName=$security_stack_name KMSKey="$EnvVariablesKmsKeyId" \
	GetAppointmentLogLevel="$GetAppointmentLogLevel" GetAppointmentSchemaPath="$GetAppointmentSchemaPath" \
	DateFrameStart="$DateFrameStart" DateFrameEnd="$DateFrameEnd" FilterRequest="$FilterRequest" \
	FilterResponse="$FilterResponse" PGUser="$PGUser" PGDatabase="$PGDatabase" PGPassword="$PGPassword" PGHost="$PGHost" \
	PGPort="$PGPort" PGTimeout="$PGTimeout" PGMaxClients="$PGMaxClients" SmartyStreetsUrl="$SmartyStreetsUrl" \
	SmartyStreetsId="$SmartyStreetsId" SmartyStreetsToken="$SmartyStreetsToken" MSUser="$MSUser" \
	MSPassword="$MSPassword" MSServer="$MSServer" MSMaxConnections="$MSMaxConnections" \
	MSMinConnections="$MSMinConnections" MSIdleTimeout="$MSIdleTimeout" MSABSDatabase="$MSABSDatabase" \
	MSOnlineStoreDatabase="$MSOnlineStoreDatabase" ReplicationDatabase="$ReplicationDatabase" \
	ReplicationPassword="$ReplicationPassword" ReplicationTimeout="$ReplicationTimeout" \
	ReplicationPort="$ReplicationPort" ReplicationMaxClients="$ReplicationMaxClients" ReplicationHost="$ReplicationHost" \
	ReplicationUser="$ReplicationUser" WOWSchedulingUrl="$WOWSchedulingUrl" \
	WOWSchedulingUsername="$WOWSchedulingUsername" WOWSchedulingPassword="$WOWSchedulingPassword" \
	OfflineResponse="$OfflineResponse" \
	SecurityGroupId="$SecurityGroupId" SubnetId1="$SubnetId1" SubnetId2="$SubnetId2" \
	--region $aws_region $profile_argument;

# Get API id
api_id=$(aws cloudformation describe-stacks --stack-name $api_stack_name --query 'Stacks[0].Outputs[?OutputKey==`ServiceAppointmentApiIdentifier`].OutputValue' --output text --region $aws_region $profile_argument);

# Dealing with the SAM bug (stage with name 'Stage' is created automatically)
stages=$(aws apigateway get-stages --rest-api-id $api_id --query 'item[*].stageName' --output text --region $aws_region $profile_argument);

for stage in $stages; do
    if [ "Stage" == "$stage" ]; then
			echo "============================================";
			echo "Deleting orphan stage: $stage from $aws_region";
			echo "============================================";
      aws apigateway delete-stage --rest-api-id $api_id --stage-name $stage --region $aws_region $profile_argument;
    fi
done

echo "============================================";
echo "Creating Deployment...";
echo "============================================";

aws apigateway create-deployment --rest-api-id $api_id --stage-name api --region $aws_region $profile_argument;

echo "============================================";
echo "Deployment created.";
echo "============================================";
