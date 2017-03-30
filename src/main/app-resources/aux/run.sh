#!/bin/bash

# do not let errors run away
set -e

# define the exit codes
SUCCESS=0

# source the ciop functions (e.g. ciop-log)
source $ciop_job_include

# add a trap to exit gracefully
clean_exit()
{
    local retval=$?
    local msg=""

    # Create return message
    case "$retval" in
    $SUCCESS) msg="Processing successfully concluded";;
    *) msg="Unknown error";;
    esac

    if [ "$retval" != "0" ]; then
        ciop-log "ERROR" "Error $retval - $msg, processing aborted"
    else
        ciop-log "INFO" "$msg"
    fi

    exit $retval
}
trap clean_exit EXIT

while read ref
do
	url=$(opensearch-client $ref enclosure)
	ciop-log "INFO" "Url: $url"
	echo "url=$url" | ciop-publish -s
done
