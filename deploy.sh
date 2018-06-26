#!/usr/bin/env bash

#Stop on error
set -e;


###### Configuration Variables Start ######
# semicolon separated list of the regions to deploy
deploy_regions="us-west-2";

version="V1";

###### Configuration Variables End  ######


print_usage() {
  (>&2 echo "Usage: $0 [-p <<aws-profile>>] [-e <<environment>>] [-a <<aws-account>>]");
	(>&2 echo -e "\tExample: $0 -p wowinc-dev-otr-DevOpsAdmin -e dev -a wowinc-dev-otr");
	(>&2 echo -e "\n\t-p\tProfile: The credential profile to use. Default: default");
	(>&2 echo -e "\n\t-e\tEnvironment: The deployment environment. Default: dev");
	(>&2 echo -e "\n\t-p\tAccount: The deployment friendly account name. Default: wowinc-dev-otr");
  exit 1;
}
# #Set environment variable
get_opts() {
	while getopts ":p:e:" opt; do
	  case $opt in
      a) export deploy_account="$OPTARG";
			;;
			e) export deploy_environment="$OPTARG";
			;;
			p) export aws_creds_profile="$OPTARG";
			;;
			y) confirm_proceed="1";
			;;
	    \?) echo "Invalid option -$OPTARG" >&2;
	    exit 1;
	    ;;
	  esac;
	done;

	return 0;
};

#Set basedir
basedir=$(dirname "$0");
# get the params passed to the script
get_opts $@;

aws_profile="${aws_creds_profile:-"default"}";
environment="${deploy_environment:-"dev"}";
account="${deploy_account:-"wowinc-dev-otr"}";

# verify args
[[ -p  "${aws_profile// }" ]] && print_usage;
[[ -p  "${environment// }" ]] && print_usage;
[[ -p  "${account// }" ]] && print_usage;

echo -e "\n:======================================:";
echo -e "\nArguments:";
echo -e "\taccount: ${account}";
echo -e "\tenvironment: ${environment}";
echo -e "\tversion: ${version}";
echo -e "\tprofile: ${aws_profile}";
echo -e "\tregions: ${deploy_regions}";
echo -e "\n:======================================:\n";
# CI will pass a -y flag that will not need to confirm
if [[ $confirm_proceed != "1" ]]; then
	read -p "Run with these arguments? [Y/n] " -n 1 -r;
	echo    # (optional) move to a new line
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		(>&2 echo "Command aborted by user.");
		[[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1; # handle exits from shell or function but don't exit interactive shell
	fi
fi



IFS=';' read -ra aws_region_name <<< "$deploy_regions"
for r in "${aws_region_name[@]}"; do
  bash $basedir/deploy_api_ServiceAppointment.sh -a "${account}" -e "${environment}" -v "${version}" -r "$r" -p "${aws_profile}";
done
