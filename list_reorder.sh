#!/bin/bash
. /etc/.profile
#set -xv

inputfile="$1"
if [ ! -f "$inputfile" ]; then
    echo "Usage: $0 <file>."
    exit 1
fi

# Create a temporary file for file processing.
temp="$(mktemp)" 

# Backup original file

grep -v "#" "$inputfile" | sort -V | sed 's/^[[:space:]]*[0-9]\+[[:space:]]*//' |  awk '{print NR $0}' | tee -a "$temp"; grep "#" "$inputfile" | tee -a "$temp"

