#!/usr/bin/env bash

#Stop on error
set -e;

WORKING_DIR=$(dirname "$0");

get_opts() {
	while getopts ":p:" opt; do
	  case $opt in
			p) export aws_creds_profile="$OPTARG";
			;;
	    \?) echo "Invalid option -$OPTARG" >&2;
	    exit 1;
	    ;;
	  esac;
	done;

	return 0;
};

get_opts $@;

aws_profile="${aws_creds_profile:-"default"}";

bash $WORKING_DIR/deploy.sh -p $aws_profile -e "dev" -a "wowinc-dev-otr";
