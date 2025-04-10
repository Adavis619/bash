#!/bin/bash
. /etc/.profile
#set -xv

: '
1. Purpose: Identify config filenames in an active environments list.fs and list.defaut file. Option to run asg_breakdown_fs if desired on the output files. Specify single host if desired.
2. Description: run "./asg_active_items.sh [host] [-b] <environment> <file keyword>".
3. Author: Anthony Davis
4. Date: 03/17/2025
'

# RUN_BRKDWN flag gives the option to run asg_breakdown_fs if desired

RUN_BRKDWN=false
VA_LIST="/$CCSYSDIR/EHR/serverlist/serverlist_va1"
SINGLE_SITE=""


while [[ $# -gt 0 ]]; do
    case "$1" in
        -b)
            RUN_BRKDWN=true

            shift

            ;;
        *)
            break

            ;;
    esac

done

# single server or server list check
if [[ $# -eq 3 ]]; then
    SINGLE_SITE="$1"
    ENV_STRING="$2"
    FILE_STRING="$3"
elif [[ $# -eq 2 ]]; then
    ENV_STRING="$1"
    FILE_STRING="$2"
else
   echo "Ex.: $0 [-b] ICU uvent "
   echo "Ex.: $0 [-b] vad1 ICU uvent "
   exit 1
fi

if [[ -n "$SINGLE_SITE" ]]; then
    VA_LIST="$SINGLE_SITE"
else
    VA_LIST=$(cat $VA_LIST)
fi

# list_dupes below checks for same filenames and prevents asg_breakdown_fs from running more than once on them.

for i in $VA_LIST; do
    YELLOW='\e[33m'
    NC='\e[0m'

    echo -e "\n${YELLOW}===== $i =====${NC}"

    ssh $i '

    RUN_BRKDWN='"${RUN_BRKDWN}"'
    declare -A list_dupes

        for v in $(.dosu UnitEnvSpread.pl | grep '"${ENV_STRING}"' | grep -v LEGACY | awk "{print \$4}" | sort -u); do

          YELLOW='"'"'\e[33m'"'"'
          GREEN='"'"'\e[32m'"'"'
          RED='"'"'\e[31m'"'"'
          NC='"'"'\e[0m'"'"'

            for file in $CCRUN/conf/webess/screens/list.fs.$v $CCRUN/conf/webess/screens/list.default.$v; do
                if [ -f "$file" ]; then
                   active_env_lists=$(sed -n -E '"'"'s/.*":screenconf":"([^"]*)".*/\1/p'"'"' "$file" | grep -i '"${FILE_STRING}"' | sort -u | tr "\n" " ")

                   if [ -n "$active_env_lists" ]; then
                      echo -e "${GREEN}$(basename "$file"):${NC} $active_env_lists"

                      if  [ "$RUN_BRKDWN" = "true" ]; then
                          for conf_file in $active_env_lists; do

                      if [[ "$conf_file" == "notesmenu.conf" ]]; then
                          echo -e "${YELLOW}Skipping:${NC} $conf_file"
                          continue
                      fi

                          if [[ -z "${list_dupes[$conf_file]}" ]]; then
                          echo -e "${YELLOW}Running:${NC} .dosu asg_breakdown_fs $conf_file"
                              .dosu asg_breakdown_fs "$conf_file" | grep -v "created"
                              list_dupes[$conf_file]=1
                             fi
                          done
                      fi
                  fi
               fi
           done
       done'

   echo ""
done
