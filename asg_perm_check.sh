#!/bin/bash
. /etc/.profile
#set -xv

: '
1. Purpose: Check a users permissions and config status or check the order of perms in default_perms.m
2. Description:
3. Author: Anthony Davis
4. Date: 04/20/2026
5. Usage: asg_perm_check.sh <USERNAME> or asg_perm_check.sh -d
'

STAFF_FILE="$CCSYSDIR/staff.m"
PERM_FILE="$CCSYSDIR/appli_perms.m"
DEFAULT_FILE="$CCSYSDIR/default_perms.m"

# FIX #7: Define functions at the top before any logic

# FIX #3: Renamed internal variable from MODE to PERM_MODE to avoid collision with script-level MODE
format_output() {
    local NUM="$1"
    local PERM_MODE="$2"

    local ACCESS=$([[ "$PERM_MODE" == "E" ]] && echo "Write" || echo "Read")
    local APP_NAME
    APP_NAME=$(awk -F':' -v n="$NUM" '$1 == n { print $NF }' "$PERM_FILE")
    [[ -z "$APP_NAME" ]] && APP_NAME="UNKNOWN"

    printf "%-12s %-30.30s %-10s\n" "$NUM" "$APP_NAME" "$ACCESS"
}

# --- Argument handling ---
if [[ "$1" == "-d" ]]; then
    MODE="DEFAULT"
elif [[ -n "$1" ]]; then
    MODE="USER"
    USER_IN="$1"
else
    echo "Usage:"
    echo "  $0 <username>"
    echo "  $0 -d"
    exit 1
fi

# --- Default mode: check default_perms.m file ---
if [[ "$MODE" == "DEFAULT" ]]; then
    echo "Checking default permissions file: $DEFAULT_FILE"
    echo

    while IFS=';' read -r GROUP PERMS; do
        [[ -z "$GROUP" || -z "$PERMS" ]] && continue

        PREV=""
        OUT_OF_ORDER=false

        for p in $PERMS; do
            CUR="${p%%:*}"

            # FIX #5: Guard against non-numeric perm entries before integer comparison
            if [[ ! "$CUR" =~ ^[0-9]+$ || ! "$PREV" =~ ^[0-9]+$ ]]; then
                PREV="$CUR"
                continue
            fi

            if [[ -n "$PREV" && "$CUR" -lt "$PREV" ]]; then
                if [[ "$OUT_OF_ORDER" == false ]]; then
                    echo "Group: $GROUP"
                    echo "  ERROR - Permissions out of order:"
                    OUT_OF_ORDER=true
                fi
                echo "    $CUR appears after $PREV"
            fi

            PREV="$CUR"
        done

        [[ "$OUT_OF_ORDER" == true ]] && echo
    done < "$DEFAULT_FILE"

    exit 0
fi

# --- User mode: check account perms ---

# Normalize username
USER_BASE="${USER_IN%@*}"
USER_UPPER=$(echo "$USER_BASE" | tr '[:lower:]' '[:upper:]')

# Find user in staff.m
LINE=$(grep -i "^$USER_UPPER;" "$STAFF_FILE")

if [[ -z "$LINE" ]]; then
    echo "User not found: $USER_IN"
    exit 1
fi

IFS=';' read -r USERNAME USERID PERMS FIRST LAST GROUP <<< "$LINE"

STAFFP_FILE="$CCSYSDIR/staff.p"
STAFF_ID="UNKNOWN"
ROLES="UNKNOWN"

# Try to find matching record in staff.p
MATCH_LINE=$(.dosu grep -i ";$FIRST;$LAST;" "$STAFFP_FILE" | grep -i ";$GROUP;" | head -1)

if [[ -n "$MATCH_LINE" ]]; then
    IFS=';' read -r RAW_ID FN LN REST <<< "$MATCH_LINE"

    STAFF_ID="staffid.$RAW_ID"

    # FIX #6: Use awk field extraction instead of fragile grep-o regex for roles
    ROLES=$(echo "$MATCH_LINE" | awk -F';' '{
        for (i=1; i<=NF; i++) {
            if ($i ~ /,/) { print $i; exit }
        }
    }' | tr -d ',')
fi

echo "Username: $USER_BASE"
echo "Staff ID: $STAFF_ID"
echo "Name: $FIRST $LAST"
echo "Group Permission: $GROUP"
echo "Role(s): $ROLES"

# --- Check Permission Order ---
PERM_NUMS=()
for p in $PERMS; do
    PERM_NUMS+=("${p%%:*}")
done

# FIX #4: Use consistent boolean variable style throughout (true/false strings)
OUT_OF_ORDER=false
PREV=""
ORDER_ERRORS=()

for CURRENT in "${PERM_NUMS[@]}"; do
    # FIX #5: Guard against non-numeric perm entries before integer comparison
    if [[ ! "$CURRENT" =~ ^[0-9]+$ || ! "$PREV" =~ ^[0-9]+$ ]]; then
        PREV="$CURRENT"
        continue
    fi

    if [[ -n "$PREV" && "$CURRENT" -lt "$PREV" ]]; then
        if [[ "$OUT_OF_ORDER" == false ]]; then
            OUT_OF_ORDER=true
        fi
        ORDER_ERRORS+=("$CURRENT appears after $PREV")
    fi
    PREV="$CURRENT"
done

# --- Compare Against default_perms.m ---

# FIX #1: Added missing grep command
DEFAULT_LINE=$(grep "^${GROUP};" "$DEFAULT_FILE")

if [[ -z "$DEFAULT_LINE" ]]; then
    echo "Config Status: ERROR - Group not found in default_perms.m"
    exit 1
fi

IFS=';' read -r DEF_GROUP DEF_PERMS <<< "$DEFAULT_LINE"

declare -A USER_MAP
declare -A DEF_MAP

# Load user perms into map
for p in $PERMS; do
    NUM="${p%%:*}"
    PERM_MODE="${p##*:}"
    USER_MAP["$NUM"]="$PERM_MODE"
done

# Load default perms into map
for p in $DEF_PERMS; do
    NUM="${p%%:*}"
    PERM_MODE="${p##*:}"
    DEF_MAP["$NUM"]="$PERM_MODE"
done

MISSING=false
EXTRA=false
MISMATCH=false

MISSING_LIST=()
EXTRA_LIST=()
MISMATCH_LIST=()

# Check for missing & mismatched perms
for NUM in "${!DEF_MAP[@]}"; do
    if [[ -z "${USER_MAP[$NUM]}" ]]; then
        MISSING=true
        MISSING_LIST+=("$NUM:${DEF_MAP[$NUM]}")
    elif [[ "${USER_MAP[$NUM]}" != "${DEF_MAP[$NUM]}" ]]; then
        MISMATCH=true
        MISMATCH_LIST+=("$NUM:${DEF_MAP[$NUM]}")
    fi
done

# Check for extra perms
for NUM in "${!USER_MAP[@]}"; do
    if [[ -z "${DEF_MAP[$NUM]}" ]]; then
        EXTRA=true
        EXTRA_LIST+=("$NUM:${USER_MAP[$NUM]}")
    fi
done

# --- Config Status Report ---
if ! $MISSING && ! $EXTRA && ! $MISMATCH && [[ "$OUT_OF_ORDER" == false ]]; then
    echo "Config Status: Permissions in order and match default_perms.m file."
else
    echo "Config Status: ERROR - Permissions DO NOT match default_perms.m file."
    echo
fi

if [[ "$OUT_OF_ORDER" == true ]]; then
    echo "Out of order entries detected:"
    for err in "${ORDER_ERRORS[@]}"; do
        echo "  $err"
    done
    echo
fi

# Missing perms
if $MISSING; then
    echo "User is missing:"
    for entry in "${MISSING_LIST[@]}"; do
        format_output "${entry%%:*}" "${entry##*:}"
    done
    echo
fi

# Extra perms
if $EXTRA; then
    echo "User should not have:"
    for entry in "${EXTRA_LIST[@]}"; do
        format_output "${entry%%:*}" "${entry##*:}"
    done
    echo
fi

# Mismatched Read/Write
if $MISMATCH; then
    echo "User should have Read/Write correction for:"
    for entry in "${MISMATCH_LIST[@]}"; do
        format_output "${entry%%:*}" "${entry##*:}"
    done
    echo
fi

# --- Current Permissions Report ---
echo "Permissions Granted:"
printf "%-12s %-30s %-10s\n" "Appli Num" "Application" "Permissions"
printf "%-12s %-30s %-10s\n" "-----------" "------------------------------" "-----------"

for p in $PERMS; do
    NUM="${p%%:*}"
    PERM_MODE="${p##*:}"
    format_output "$NUM" "$PERM_MODE"
done