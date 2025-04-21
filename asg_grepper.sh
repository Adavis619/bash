#!/usr/bin/env bash

# ── CONFIG ────────────────────────────────────────────────────────────────────
items_dir="$CCRUN/conf/webess/flowsheets/items"

YELLOW='\e[33m'
GREEN='\e[32m'
RED='\e[31m'
NC='\e[0m'

# ── USAGE CHECK ───────────────────────────────────────────────────────────────
if [ $# -eq 0 ]; then
  echo "Usage: $0 [\"pattern1\" …] [file1.conf …]" >&2
  exit 1
fi

# ── STEP 1: partition args ────────────────────────────────────────────────────
string_args=()
file_args=()
for arg in "$@"; do
  if [[ -r "$items_dir/$arg" ]]; then
    file_args+=( "$arg" )
  else
    string_args+=( "$arg" )
  fi
done

# ── STEP 1b: if any literal strings, do only that and exit ────────────────────
if (( ${#string_args[@]} > 0 )); then
  # escape & wrap each in quotes
  quoted=()
  for s in "${string_args[@]}"; do
    esc=${s//\"/\\\"}
    quoted+=( "\"$esc\"" )
  done
  # join with '|'
  dbis=$( IFS="|"; echo "${quoted[*]}" )

  # single combined grep
  echo -e "${GREEN}grep -E '(${dbis})' site_dbshm.cf${NC}"
  exit 0
fi

# ── STEP 2: for each .conf file, extract DBIs and grep ─────────────────────────
for file in "${file_args[@]}"; do
  echo -e "${YELLOW}$file${NC}"
  echo -n "${GREEN}grep -E '("

  dbis=$(
    grep '^[^#]' "$items_dir/$file" \
      | awk -F'[' '{print $1}' \
      | sed 's/^[[:space:]]*"/"/;s/[[:space:]]*$/"\|/' \
      | tr -d '\n' \
      | sed -r 's/(.*)\|/\1/'
  )

  echo -e "${dbis})' site_dbshm.cf${NC}"
  echo
done

exit 0
