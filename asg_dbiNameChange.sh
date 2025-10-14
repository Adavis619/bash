#!/bin/bash

. /etc/.profile
#set -xv

: '
1. Purpose: Update DBI Display Names and Full Names in site_dbshm.cf
2. Description: run "asg_dbiNameChange <dbiNameChanges_file>".
3. Author: Anthony Davis
4. Date: 10/07/2025
5. Usage: asg_dbiNameChange <path_to_dbiNameChanges_file>
'

# Check if argument is provided
if [ $# -eq 0 ]; then
    echo "Error: No dbiNameChanges file specified"
    echo "Usage: $0 <path_to_dbiNameChanges_file>"
    exit 1
fi

DBI_CHANGES_FILE="$1"

# Verify the file exists
if [ ! -f "$DBI_CHANGES_FILE" ]; then
    echo "Error: File '$DBI_CHANGES_FILE' not found"
    exit 1
fi

echo "Starting DBI Name Change Process"
echo "Using dbiNameChanges file: $DBI_CHANGES_FILE"

# Push dbiNameChanges file
echo "Pushing dbiNameChanges file to all primary hosts..."

for i in asgcon1; do
    scp "$DBI_CHANGES_FILE" $i:/usr/tmp/dbiNameChanges >/dev/null 2>&1
    ssh $i 'chmod 770 /usr/tmp/dbiNameChanges'
done

echo "dbiNameChanges file pushed successfully"

# Start dbi changes at each host
for i in asgcon1; do
    echo "Updating host: $i"

    ssh -T $i << 'ENDSSH'

        # For the backup filename
        buExt=$(date +%Y%m%d)

        # Make the log file
        logname="/usr/tmp/$HOST.dbichanges.txt"
        .dosu touch $logname
        .dosu chmod 777 $logname

        # Make temp files
        .dosu cp $CCSYSDIR/site_dbshm.cf /usr/tmp/site_dbshm.cf.$HOST
        .dosu cp $CCSYSDIR/site_dbshm.cf /usr/tmp/site_dbshm.cf.$HOST.2
        .dosu chmod 777 /usr/tmp/site_dbshm.cf.$HOST*

        # Process changes
        extract_field() {
            local line="$1"
            local field_num="$2"
            echo "$line" | awk -F'"' -v fn=$((field_num * 2)) '{print $fn}'
        }

        field_value_exists() {
            local file="$1"
            local field_num="$2"
            local value="$3"
            local exclude_internal="$4"

            if [ -n "$exclude_internal" ]; then
                awk -F'"' -v fn=$((field_num * 2)) -v val="$value" -v excl="$exclude_internal" '$2 != excl && $fn == val {found=1; exit} END {exit !found}' "$file"
            else
                awk -F'"' -v fn=$((field_num * 2)) -v val="$value" '$fn == val {found=1; exit} END {exit !found}' "$file"
            fi
        }

        make_unique() {
            local file="$1"
            local field_num="$2"
            local value="$3"
            local internal_name="$4"
            local modified="$value"

            while field_value_exists "$file" "$field_num" "$modified" "$internal_name"; do
                modified="$modified "
            done

            echo "$modified"
        }

        echo "=== Updating DBIs at $HOST ===" | tee -a "$logname"
        echo "Start: $(date)" | tee -a "$logname"

        while IFS= read -r new_line; do
            [[ -z "$new_line" || "$new_line" =~ ^[[:space:]]*# ]] && continue

            internal_name=$(extract_field "$new_line" 1)

            if [ -z "$internal_name" ]; then
                echo "Warning: Could not extract internal name" | tee -a "$logname"
                continue
            fi

            if ! grep -q "^\"$internal_name\"" /usr/tmp/site_dbshm.cf.$HOST; then
                echo "Warning: DBI '$internal_name' not found" | tee -a "$logname"
                continue
            fi

            new_display=$(extract_field "$new_line" 2)
            new_fullname=$(extract_field "$new_line" 3)

            unique_display=$(make_unique "/usr/tmp/site_dbshm.cf.$HOST" 2 "$new_display" "$internal_name")
            unique_fullname=$(make_unique "/usr/tmp/site_dbshm.cf.$HOST" 3 "$new_fullname" "$internal_name")

            if [ "$new_display" != "$unique_display" ]; then
                echo "Info: Requested Display Name had to be modified to '$unique_display'" | tee -a "$logname"
            fi

            if [ "$new_fullname" != "$unique_fullname" ]; then
                echo "Info: Requested Full Name had to be modified to '$unique_fullname'" | tee -a "$logname"
            fi

            modified_line=$(echo "$new_line" | awk -F'"' -v disp="$unique_display" -v full="$unique_fullname" '{OFS="\""; $4=disp; $6=full; print}')

            awk -v internal="$internal_name" -v newline="$modified_line" '
                $0 ~ "^\"" internal "\"" {print newline; next}
                {print}
            ' /usr/tmp/site_dbshm.cf.$HOST.2 | .dosu tee /usr/tmp/site_dbshm.cf.$HOST.tmp > /dev/null
            .dosu mv /usr/tmp/site_dbshm.cf.$HOST.tmp /usr/tmp/site_dbshm.cf.$HOST.2

            echo "Updated: $internal_name" | tee -a "$logname"

        done < /usr/tmp/dbiNameChanges

        echo "Completed: $(date)" | tee -a "$logname"

        # Make the changes live
        echo "Activating modified site_dbshm.cf"

        cd $CCSYSDIR/
        if [ ! -f /usr/tmp/site_dbshm.cf.$HOST.2 ]; then
            echo -e "Staged file not found. Review issues with script."
            exit 1
        fi

        .dosu cp site_dbshm.cf site_dbshm.cf.dbiMod.$buExt
        .dosu asgr site_dbshm.cf.dbiMod.$buExt
        echo -e "Backup created: $(ls -ltr $PWD/site_dbshm.cf.dbiMod.$buExt)"
        .dosu cp /usr/tmp/site_dbshm.cf.$HOST.2 site_dbshm.cf
        sleep 1
        .dosu Rloaddbshm
        .dosu asgr site_dbshm.cf
        .dosu CTImport -f site_dbshm.cf
        adiff site_dbshm.cf site_dbshm.cf.dbiMod.$buExt | tee -a "$logname"

        echo "Log file: /usr/tmp/$HOST.dbichanges.txt"

ENDSSH

    echo "Completed site: $i"
    echo "---"
done

echo "All hosts updated successfully"