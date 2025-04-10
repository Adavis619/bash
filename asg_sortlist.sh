#!/bin/bash
. /etc/.profile
#set -xv

: '
1. Purpose: Process and renumber list files
2. Description: run ".dosu ./asg_sortlist inputfile"
3. Author: 
4. Date: 04/09/2025
5. Usage: ./asg_sortlist inputfile
'

# Define color codes
YELLOW='\e[33m'
GREEN='\e[32m'
RED='\e[31m'
NC='\e[0m'


# Check for file
if [ "$#" -ne 1 ]; then
    echo -e "\n${YELLOW}Usage${NC}: $0 list.*"
    exit 1
fi

input_file="$1"

# Ensure provided file is a list file
if [[ $(basename "$input_file") != list.* ]]; then
    echo -e "${RED}Error: The input file must start with 'list.'${NC}"
    exit 1
fi

# Make backup
echo -e "${YELLOW}Making backup file: $input_file.bkup"
.dosu cp -p "$input_file" "$input_file".bkup

# Make temp files
temp_sorted=$(mktemp)

# Process lines that start with a number:
grep '^[0-9]' "$input_file" | sed 's/^[0-9]*//g' | awk '{print NR $0}' | .dosu tee -a "$temp_sorted" > /dev/null

# Process all other lines
grep -v '^[0-9]' "$input_file" | .dosu tee -a "$temp_sorted" > /dev/null

# Replace the original file with the sorted file
.dosu mv "$temp_sorted" "$input_file"
.dosu chmod 640 "$input_file"

# Display the updated file
echo -e "${GREEN}$input_file renumbered.${NC}"
cat "$input_file"
