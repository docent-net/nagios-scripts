#! /bin/bash
##############################################################################
# Log file changes detector plugin for Nagios. Basicly this script checks
# if there were any changes made (mtime) in particular file during given time
# interval.
#
#	This script takes below parameters (some of those are optional):
#		-f filename (with full path)
#		-h deadline hour for log generation in format HH:MM:SS
#		-w (optional) replace part of logfilename with weekday number
#		-z hours interval, that will be checked before deadline (so
#		   if the file was modified between deadline and deadline - hours
#		   than everything is OK). format: int
#
#	Example usage:
#	./check_file_changes.sh -f somelogfile/file_:WEEK:.txt -h 00:00:00 -r :WEEK: -z 8
#
##############################################################################

FIND=/usr/bin/find
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

DEBUG=0 # set to 1 in order to see dbg messages

# reading and checking params passed by user
testParams()
{
	while getopts ":f:h:r:z:" OPT; do
		case ${OPT} in
			f) param_filename=$OPTARG; ;;
			h) param_time=$OPTARG; ;;
			r) param_weektoken=$OPTARG; ;;
			z) param_hours=$OPTARG; ;;
			\?)
			echo "Unknown option: -$OPTARG" >&2
			exit $STATE_UNKNOWN; ;;
			:)
			echo "Option -$OPTARG requires an argument." >&2
			exit $STATE_UNKNOWN;
			;;
		esac
	done
	
	# some params are obligatory and can't be empty
	if [[ -z $param_filename || -z $param_time || -z $param_hours ]]; then
		echo "UNKNOWN: You must supply all arguments -f somelogfile.log -h HH:MM:SS -z hours";
		exit $STATE_UNKNOWN;
	fi
	
	# let's check if time params are given in proper format:
	REGEXP=[0-9][0-9]:[0-9][0-9]:[0-9][0-9]
	if [[ ! $param_time =~ $REGEXP ]]; then
		echo "Wrong format of time param - should be HH:MM:SS";
		exit $STATE_UNKNOWN;
	fi
	
	return 0
}

testFile()
{
	# let's set time interval borders:
	DATE_TODAY=`date +"%Y-%m-%d"`
	
	TIME_NOW="$DATE_TODAY "`date +"%H:%M:%S"`
	TIMESTAMP_NOW=`date -d "$TIME_NOW" +"%s"`
	
	DEADLINE_TIMESTAMP=`date -d "$DATE_TODAY $param_time" "+%s"`
	DEADLINE_DATE="$DATE_TODAY $param_time"
	
	BOTTOM_TIMESTAMP=$(( $DEADLINE_TIMESTAMP-($param_hours*60*60) ))
	BOTTOM_DATE=`date -d "@$BOTTOM_TIMESTAMP" +"%Y-%m-%d %H:%M:%S"`
			
	# when commiting check before DEADLINE moment than we should check within
	# last 24h
	if (( $TIMESTAMP_NOW <= $DEADLINE_TIMESTAMP )); then
			BOTTOM_TIMESTAMP=$(( $DEADLINE_TIMESTAMP-((24+$param_hours)*60*60) ))
			BOTTOM_DATE=`date -d "@$BOTTOM_TIMESTAMP" +"%Y-%m-%d %H:%M:%S"`
	fi
	
	DIR=`dirname $param_filename`
	FILE=`basename $param_filename`
	
	if (( $DEBUG == 1 )); then
		echo "TIME_NOW: $TIME_NOW"
		echo "TIMESTAMP_NOW: $TIMESTAMP_NOW"
		echo "DEADLINE_TIMESTAMP: $DEADLINE_TIMESTAMP"
		echo "DEADLINE_DATE: $DEADLINE_DATE"
		echo "BOTTOM_TIMESTAMP: $BOTTOM_TIMESTAMP"
		echo "BOTTOM_DATE: $BOTTOM_DATE"
		
		echo $DIR
		echo $FILE
	fi
	
	# if user passed a param -r than we have to replace part of filename
	# (token passed in -r param) with week number
	if [ ! -z $param_weektoken ]; then
		FILE=${FILE/$param_weektoken/`date +"%V"`}
	fi
	
	if [ ! -d $DIR ]; then
		echo "Directory $DIR does NOT exist!"
		exit $STATE_UNKNOWN
	fi
	
	TEST=`$FIND $DIR -type f -name "$FILE" -newermt "$BOTTOM_DATE" ! -newermt "$DEADLINE_DATE" | wc -l`
	if (( $TEST == 0 )); then
		echo "File $DIR/$FILE was not found!"
		exit $STATE_CRITICAL
	elif (( $TEST > 1 )); then
		echo "Looks like there is more than 1 file $DIR/$FILE... WTF?"
		exit $STATE_UNKNOWN
	fi
}

testParams "${@}"

testFile

echo "OK, found file $DIR/$FILE modified between $BOTTOM_DATE and $DEADLINE_DATE"
exit $STATE_OK