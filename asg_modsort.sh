#!/bin/bash

. /etc/.profile

YELLOW='\e[33m'
GREEN='\e[32m'
RED='\e[31m'
NC='\e[0m'

sort_only=false

# Parse optional flag
if [ "$1" == "-s" ] || [ "$1" == "--sort-only" ]; then
  sort_only=true
  shift
fi

if [ "$#" -ne 1 ]; then
  echo -e "\n${YELLOW}Usage${NC}: $0 [-s|--sort-only] list.*"
  exit 1
fi

input_file="$1"

if [[ $(basename "$input_file") != list.* ]]; then
  echo -e "${RED}Error: The input file must start with 'list.'${NC}"
  exit 1
fi

echo -e "${YELLOW}Making backup file: $input_file.bkup"
.dosu cp -p "$input_file" "$input_file".bkup

temp_sorted=$(mktemp)

if [ "$sort_only" = true ]; then
  # Sort by numeric prefix, keeping the prefix
  grep '^[0-9]' "$input_file" | sort -n | .dosu tee "$temp_sorted" > /dev/null
else
  # Default behavior: remove number, renumber sequentially
  grep '^[0-9]' "$input_file" | sed 's/^[0-9]*//g' | awk '{print NR $0}' | .dosu tee "$temp_sorted" > /dev/null
fi

# Add remaining lines (non-numbered)
grep -v '^[0-9]' "$input_file" | .dosu tee -a "$temp_sorted" > /dev/null

.dosu mv "$temp_sorted" "$input_file"
.dosu chmod 640 "$input_file"

echo -e "${GREEN}$input_file processed.${NC}"