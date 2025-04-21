#!/bin/bash
. /etc/.profile
#set -xv

: '
1. Purpose: To make DBI grep tasks quicker, retrieve the DBIs in an items file and display them on one line.
2. Description: dbi_grepper.sh
3. Author: Anthony Davis
4. Date: 04/17/2025
5. Usage: asg_ez_dbigrep.sh <file1> <file2>
'

# set items directory path
items_dir="$CCRUN/conf/webess/flowsheets/items"

# Define color codes
YELLOW='\e[33m'
GREEN='\e[32m'
RED='\e[31m'
NC='\e[0m'

# check for argument
inputfile="$1"

if [ -z "$inputfile" ]; then
  echo "Usage: $0 <file1> <file2>"
  exit 1
fi

# echo the filename to user
output=$(for file in "$@"; do
             echo -e "${YELLOW}$file${NC}"
             echo -e -n "${GREEN}grep -E '(${NC}"
             # then confirm items path
             path="$items_dir/$file"

             if [[ ! -r "$path" ]]; then
                 echo "$path not found">&2
                 continue
             fi

# get non-commented lines, isolate dbis, replace leading/trailing whitespace with quotes and pipes, then output to one line. Final sed to add new line for loops.
grep '^[^#]' "$path" | awk -F'[' '{print $1}' | sed 's/^[[:space:]]*/"/;s/[[:space:]]*$/"\|/' | tr -d '\n' | sed $'$s/$/\\\n/' | sed -r 's/(.*)\|/\1/'; done)
if [ -n "$output" ]; then echo -e -n "\n$output${GREEN})' site_dbshm.cf${NC}"; fi

echo

exit 0

