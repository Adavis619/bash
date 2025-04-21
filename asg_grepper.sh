#!/bin/bash
. /etc/.profile
#set -xv

items_dir="$CCRUN/conf/webess/flowsheets/items"

YELLOW='\e[33m'
GREEN='\e[32m'
RED='\e[31m'
NC='\e[0m'

if [ $# -eq 0 ]; then
  echo "Usage: $0 [\"pattern1\" ] [file1.conf ]" >&2
  exit 1
fi

shopt -s nullglob

string_args=()
file_args=()
for arg in "$@"; do
    if [[ "$arg" == *[\*\?\[]* ]]; then
        matches=( "$items_dir"/$arg )
        if (( ${#matches[@]} )); then
            for full in "${matches[@]}"; do
                file_args+=( "$(basename "$full")" )
            done
        else
            echo -e "${RED}Warning:${NC} no files match pattern '$arg'" >&2
        fi
    elif [[ -r "$items_dir/$arg" ]]; then
        file_args+=( "$arg" )
    else
        string_args+=( "$arg" )
  fi
done

if (( ${#string_args[@]} > 0 )); then
    if (( ${#file_args[@]} > 0 )); then
        full_paths=( "${file_args[@]/#/$items_dir/}" )
        for s in "${string_args[@]}"; do
            if ! grep -Fq "$s" "${full_paths[@]}"; then
                echo -e "${RED}Error:${NC} string '$s' not found in any files." >&2
            fi
        done
    fi

 quoted=()
  for s in "${string_args[@]}"; do
    esc=${s//\"/\\\"}
    quoted+=( "\"$esc\"" )
  done
  # join with '|'
  dbis=$( IFS="|"; echo "${quoted[*]}" )

  if (( ${#file_args[@]} > 0 )); then
      if (( ${#file_args[@]} > 3 )); then
          display=( "${file_args[@]:0:3}" )
          more_count=$(( ${#file_args[@]} -3 ))
          echo -e "${YELLOW}${display[*]} ... and ${more_count} more files.${NC}"
      else
          echo -e "${YELLOW}${file_args[@]}${NC}"
      fi

      echo -e "${GREEN}grep -E '(${NC}${dbis}${GREEN})' site_dbshm.cf${NC}"

  exit 0
fi

  echo -e "${GREEN}grep -E '(${NC}${dbis}${GREEN})' site_dbshm.cf${NC}"
  exit 0
fi

for file in "${file_args[@]}"; do
  echo -e "${YELLOW}$file${NC}"
  echo -e -n "${GREEN}grep -E '(${NC}"

  dbis=$(
    grep '^[^#]' "$items_dir/$file" \
      | awk -F'[' '{print $1}' \
      | sed 's/^[[:space:]]*/"/;s/[[:space:]]*$/"\|/' \
      | tr -d '\n' \
      | sed -r 's/(.*)\|/\1/'
  )

  echo -e "${dbis}${GREEN})' site_dbshm.cf${NC}"
  echo
done

exit 0
