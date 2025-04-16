#!/bin/bash
. /etc/.profile
#set -xv

inputfile="$1"
if [ ! -f "$inputfile" ]; then
    echo "Error: File '$inputfile' not found."
    exit 1
fi

# Create a temporary file for file processing.
temp=$(mktemp)

grep -v "#" $inputfile | sort -V | sed 's/^[[:space:]]*[0-9]\+[[:space:]]*//' |  awk '{print NR $0}' | tee -a $mktemp; grep "#" $inputfile | tee -a $mktemp
