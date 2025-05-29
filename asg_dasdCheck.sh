#!/bin/bash
. /etc/.profile
#set -xv

: '
1. Purpose: Check to see status of START_DASD in CHKDAEMONS.$HOST.cf file. Alert sent if dasd is running on host, but START_DASD is commented out.
2. Description: asg_dasdCheck.sh
3. Author: Anthony Davis
4. Date: 04/10/2025
5. Usage: asg_dasdCheck.sh run via cis cron job.
'


echo `date`" Start asg_dasdCheck.sh"

for i in `cat /$CCSYSDIR/EHR/serverlist/serverlist_monitor_VA`; do
alerts=$(
dasdchk=$(ssh -n $i 'cd $CCSYSDIR; P dasd | grep -w dasd | grep $CAMPUS >/dev/null && grep -w "^#.*START_DASD" CHKDAEMONS.$HOST.cf');
if echo "$dasdchk" | grep -q START_DASD; then echo -e "Check the following configuration in file: \$CCSYSDIR/CHKDAEMONS.\$HOST.cf:\n $dasdchk"; fi)

#if [ -n "$alerts" ]; then echo "$alerts" | mailx -s "[ASG][asg_dasdCheck.sh][OG]: $i: START_DASD commented out in CHKDAEMONS.\$HOST.cf" anthony.davis@clinicomp.com; fi
if [ -n "$alerts" ]; then echo "$alerts" | mailx -s "[ASG][asg_dasdCheck.sh][OG]: $i: START_DASD commented out in CHKDAEMONS.\$HOST.cf" asgp2@clinicomp.opsgenie.net; fi

done

echo `date`" End asg_dasdCheck.sh"

###################################################

#!/bin/bash
. /etc/.profile
#set -xv

: '
1. Purpose: Check to see status of START_DASD in CHKDAEMONS.$HOST.cf file. Alert sent if dasd is running on host, but START_DASD is commented out.
2. Description: asg_dasdCheck.sh
3. Author: Anthony Davis
4. Date: 04/10/2025
5. Usage: asg_dasdCheck.sh run via cis cron job.
'


echo `date`" Start asg_dasdCheck.sh"

for i in `cat /$CCSYSDIR/EHR/serverlist/serverlist_monitor_VA`; do
alerts=$(
dasdchk=$(ssh -n $i 'cd $CCSYSDIR; P dasd | grep -w dasd | grep $CAMPUS >/dev/null && grep -w START_DASD CHKDAEMONS.$HOST.cf');
	if echo "$dasdchk" | grep -q "#" CHKDAEMONS.$HOST.cf | grep START_DASD; then 
		echo -e "Check the following configuration in file: \$CCSYSDIR/CHKDAEMONS.\$HOST.cf:\n $dasdchk";
			else
				dasdrun=$(P dasd | grep -w dasd | grep $CAMPUS)
				dascom=$(grep -q "^\$.*START_DASD" CHKDAEMONS.$HOST.cf)
					if [ -n "$dasdrun" && "$dascom" ]; then 
					echo -e "DASD is running" >/dev/null; 
				else 
					if [ -z "$dasdrun" ] && [ -n $dascom]; then 
					echo -e "$HOST: START_DASD is enabled, but DASD is not running.";
			fi	
		fi
	fi
)

if [ -n "$alerts" ]; then echo "$alerts" | mailx -s "[ASG][asg_dasdCheck.sh][OG]: $i: DASD issue found." asgp2@clinicomp.opsgenie.net; fi

done

echo `date`" End asg_dasdCheck.sh"
