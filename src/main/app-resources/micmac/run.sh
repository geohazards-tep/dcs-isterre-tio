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

# switch to TMPDIR
TMPDIR=/tmp/foobar
ciop-log "INFO" "Change dir to '$TMPDIR'"
cd $TMPDIR

while read line
do
    if [ "x$(echo $line|cut -c1-4)" != "xurl=" ]; then
        continue
    fi
    image_url=$(echo $line|cut -c5-)
	ciop-log "INFO" "Fetching: $image_url"
    #ciop-copy -o $TMPDIR $image_url
done
