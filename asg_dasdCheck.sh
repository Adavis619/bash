#!/bin/bash
. /etc/.profile
#set -xv

: '
1. Purpose: Check to see status of START_DASD in CHKDAEMONS.$HOST.cf file.
   Alert is sent in either of two cases:
   - DASD is running, but START_DASD is commented out.
   - START_DASD is enabled, but DASD is not running.
2. Description: asg_dasdCheck.sh
3. Author: Anthony Davis
4. Date: 04/10/2025 (Updated)
5. Usage: asg_dasdCheck.sh run via cis cron job.
'

echo "$(date) Start asg_dasdCheck.sh"

for i in $(cat /$CCSYSDIR/EHR/serverlist/serverlist_monitor_VA); do
alerts=$(
ssh -n "$i" '
  cd $CCSYSDIR

  # Check if DASD process is running
  P dasd | grep -w dasd | grep $CAMPUS > /dev/null
  dasd_status=$?

  # Check START_DASD line status
  commented=$(grep -w "^#.*START_DASD" CHKDAEMONS.$HOST.cf)
  enabled=$(grep -w "^\$.*START_DASD" CHKDAEMONS.$HOST.cf)

  # Alert if DASD is running but START_DASD is commented
  if [ $dasd_status -eq 0 ] && [ -n "$commented" ]; then
    echo -e "Check the following configuration in file: \$CCSYSDIR/CHKDAEMONS.\$HOST.cf:\nDASD process is running, but START_DASD is commented out:\n$commented"
  fi

  # Alert if START_DASD is enabled but DASD is not running
  if [ $dasd_status -ne 0 ] && [ -n "$enabled" ]; then
    echo -e "Check the following configuration in file: \$CCSYSDIR/CHKDAEMONS.\$HOST.cf:\nSTART_DASD is enabled, but DASD process is NOT running."
  fi
'
)

# Send alert if any mismatch found
if [ -n "$alerts" ]; then
  echo "$alerts" | mailx -s "[ASG][asg_dasdCheck.sh][OG]: $i: START_DASD config mismatch in CHKDAEMONS.\$HOST.cf" asgp2@clinicomp.opsgenie.net
fi

done

echo "$(date) End asg_dasdCheck.sh"
