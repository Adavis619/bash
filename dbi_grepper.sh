#!/bin/bash
. /etc/.profile
#set -xv

: '
1. Purpose: To make DBI grep tasks quicker, retrieve the DBIs in an items file and display them on one line.
2. Description: dbi_grepper.sh
3. Author: Anthony Davis
4. Date: 04/17/2025
5. Usage: dbi_grepper.sh <file1> <file2>
'
items_dir="$CCRUN/conf/webess/flowsheets/items"
# Define color codes
YELLOW='\e[33m'
GREEN='\e[32m'
RED='\e[31m'
NC='\e[0m'

inputfile="$1"

if [[ -z "$inputfile" || ! -f "$inputfile" ]]; then
  echo "Usage: $0 <file1> <file2>"
  exit 1
fi

# echo the filename, get non-commented lines, isolate dbis, replace leading/trailing whitespace with quotes and pipes, then output to one line. Final sed to add new line for loops.
output=$(for file in "$@"; do 
echo -e "${YELLOW}$file${NC}"
path="$items_dir/$file"

if [[ ! -r "$path" ]]; then
  echo "$path not found or unreadable">&2
  continue
fi

echo "grepping: $path" >&2

grep '^[^#]' "$path" | awk -F'[' '{print $1}' | sed 's/^[[:space:]]*/"/;s/[[:space:]]*$/"\|/' | tr -d '\n' | sed $'$s/$/\\\n/'; done)
#output=$(for file in "$@"; do echo -e "${YELLOW}$file${NC}"; grep '^[^#]' "$file" | awk -F'[' '{print $1}' | sed 's/^[[:space:]]*/"/;s/[[:space:]]*$/"\|/' | tr -d '\n' | sed $'$s/$/\\\n/'; echo; done)
if [ -n "$output" ]; then echo -n "$output"; fi

echo

exit 0
