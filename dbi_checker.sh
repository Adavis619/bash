#!/bin/bash
. /etc/.profile
#set -xv

: '
1. Purpose: Via a list file or individual dbi arguments, check DBIs for active use at hosts.
2. Description: run "./dbi_checker.sh <inputfile> OR ./dbi_checker.sh "dbi 1" "dbi 2" ...
3. Author: Anthony Davis
4. Date: 04/22/2025
5. Usage: ./dbi_checker.sh <input_file> OR ./dbi_checker.sh "dbi 1" "dbi 2" ...
'

# Spinner function
spin() {
    local message="$1"
    local -a spin_marks=('/' '-' '\' '|')
    while :; do
        for m in "${spin_marks[@]}"; do
            printf "\r[%s] Checking DBI: $term..." "$m"
            sleep 0.1
        done
    done
}

spin_pid=""

# Handle Ctrl+C gracefully. It will sping for eternity without this.
cleanup() {
      [[ -n "$spin_pid" ]] && kill "$spin_pid" &>/dev/null
        echo -e "\nInterrupted. Exiting..."
          exit 130
          }
trap cleanup INT

# Start script
# Usage check
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <input_file> OR $0 \"string1\" \"string2\" ..."
    exit 1
fi

# Define and check server list
server_list="/$CCSYSDIR/EHR/serverlist/serverlist_va1"
if [[ ! -f "$server_list" ]]; then
    echo "Error: server list not found at $server_list"
    exit 2
fi

# check for a file or string(s)
if [[ -f "$1" ]]; then
    mapfile -t search_terms < "$1"
else
    search_terms=( "$@" )
fi

# Results storage
declare -a in_use
declare -a not_in_use

# Main loop
for term in "${search_terms[@]}"; do
    found=0
    # Run the spinner in the background
    message="Searching for \"$term\"..."
    spin "$message" &
    spin_pid=$!
    for server in $(cat "$server_list"); do
        result=$(ssh -n "$server" ".dosu asg_finddbi_fs \"$term\"" 2>/dev/null | grep conf)
        if [[ -n "$result" ]]; then
            in_use+=( "\"$term\"" )
            found=1
            # if a dbi is found, then stop searching for it at other sites
            break
        fi
    done
    # Stop the spinner
    kill "$spin_pid" &>/dev/null
    wait "$spin_pid" 2>/dev/null
    # Return and clear line
    printf "\r\033[K"

    # Remove the spinner then show results
    if [[ $found -eq 1 ]]; then
        printf "In use: \"$term\"\n"

    else
        printf "NOT in use: \"$term\""
        not_in_use+=( "\"$term\"" )
    fi
done

# Final report
echo -e "\n====== DBI Usage Report ======"

if [ ${#in_use[@]} -gt 0 ]; then
    echo -e "\n--- In Use ---"
    printf '%s\n' "${in_use[@]}"
else
    echo -e "\n--- In Use ---\nNone"
fi

if [ ${#not_in_use[@]} -gt 0 ]; then
    echo -e "\n--- Not In Use ---"
    printf '%s\n' "${not_in_use[@]}"
else
    echo -e "\n--- Not In Use ---\nNone"
fi
