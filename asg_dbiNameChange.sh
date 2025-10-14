#!/bin/bash
#
# Script: asg_dbiNameChange
# Purpose: Update DBI Display Names and Full Names in site_dbshm.cf
# Input: dbiNameChanges file path as command-line argument
# Usage: asg_dbiNameChange <path_to_dbiNameChanges_file>
#

# Check if argument provided
if [ $# -ne 1 ]; then
    echo "Error: Missing required argument"
    echo "Usage: $0 <path_to_dbiNameChanges_file>"
    echo "Example: $0 /ccrun/cci/run/dbiNameChanges"
    exit 1
fi

# Get the full path to the file (handles both relative and absolute paths)
DBI_FILE=$(realpath "$1")
if [ ! -f "$DBI_FILE" ]; then
    echo "Error: File not found: $DBI_FILE"
    exit 1
fi

# Extract just the filename for remote operations
DBI_FILENAME=$(basename "$DBI_FILE")

# Sites being updated
SITE=/ccrun/cci/run/EHR/serverlist/serverlist_masterdbpush

# Main script execution
echo "Starting DBI Name Change Process"
echo "Using dbiNameChanges file: $DBI_FILE"

# Push dbiNameChanges file to sites
echo "Pushing $DBI_FILENAME to sites..."
for i in $(cat $SITE | grep -v ^# | grep -v ehr2 | grep -v qcci01); do
    scp "$DBI_FILE" $i:/usr/tmp/$DBI_FILENAME >/dev/null 2>&1
    ssh $i "chmod 770 /usr/tmp/$DBI_FILENAME"
done

echo "$DBI_FILENAME file pushed successfully"

# Process changes at each site
for i in $(cat $SITE | grep -v ^# | grep -v ehr2 | grep -v qcci01); do
    echo "Processing site: $i"
    
    ssh $i << 'ENDSSH'
        # For naming backup file
        buExt=$(date +%Y%m%d)
        
        # Make the logfile
        logname="/usr/tmp/$USER.dbichanges.txt"
        .dosu touch $logname
        .dosu chmod 777 $logname
        
        # Gather temp files
        .dosu cp $CCSYSDIR/site_dbshm.cf /usr/tmp/site_dbshm.cf.$HOST
        .dosu cp $CCSYSDIR/site_dbshm.cf /usr/tmp/site_dbshm.cf.$HOST.2
        .dosu chmod 777 /usr/tmp/site_dbshm.cf.$HOST*
        
        # Process changes (call function)
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
                awk -F'"' -v fn=$((field_num * 2)) -v val="$value" -v excl="$exclude_internal" \
                    '$2 != excl && $fn == val {found=1; exit} END {exit !found}' "$file"
            else
                awk -F'"' -v fn=$((field_num * 2)) -v val="$value" \
                    '$fn == val {found=1; exit} END {exit !found}' "$file"
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
        
        echo "=== Processing DBI Changes at $HOST ===" | tee -a "$logname"
        echo "Start time: $(date)" | tee -a "$logname"
        
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
                echo "Info: Display name modified to '$unique_display'" | tee -a "$logname"
            fi
            
            if [ "$new_fullname" != "$unique_fullname" ]; then
                echo "Info: Full name modified to '$unique_fullname'" | tee -a "$logname"
            fi
            
            modified_line=$(echo "$new_line" | awk -F'"' -v disp="$unique_display" -v full="$unique_fullname" \
                '{OFS="\""; $4=disp; $6=full; print}')
            
            # Delete the old line and replace it with the new one in the same position
            awk -v internal="$internal_name" -v newline="$modified_line" '
                $0 ~ "^\"" internal "\"" {print newline; next}
                {print}
            ' /usr/tmp/site_dbshm.cf.$HOST.2 | .dosu tee /usr/tmp/site_dbshm.cf.$HOST.tmp > /dev/null
            .dosu mv /usr/tmp/site_dbshm.cf.$HOST.tmp /usr/tmp/site_dbshm.cf.$HOST.2
            
            echo "Updated: $internal_name" | tee -a "$logname"
            
        done < /usr/tmp/$DBI_FILENAME
        
        echo "Completed processing at $(date)" | tee -a "$logname"
        
        # Activate the changes
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
ENDSSH
    
    echo "Completed site: $i"
    echo "---"
done

echo "All sites processed successfully"