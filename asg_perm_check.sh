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
STAFFP_FILE="$CCSYSDIR/staff.p"

########################################
# Format Output
########################################
format_output() {
    local NUM="$1"
    local PERM_MODE="$2"

    local ACCESS=$([[ "$PERM_MODE" == "E" ]] && echo "Write" || echo "Read")
    local APP_NAME
    APP_NAME=$(awk -F':' -v n="$NUM" '$1 == n { print $NF }' "$PERM_FILE")
    [[ -z "$APP_NAME" ]] && APP_NAME="UNKNOWN"

    printf "%-12s %-30.30s %-10s\n" "$NUM" "$APP_NAME" "$ACCESS"
}

########################################
# Argument Handling
########################################
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

########################################
# DEFAULT MODE
########################################
if [[ "$MODE" == "DEFAULT" ]]; then
    echo "Checking default permissions file: $DEFAULT_FILE"
    echo

    while IFS=';' read -r GROUP PERMS; do
        [[ -z "$GROUP" || -z "$PERMS" ]] && continue

        PREV=""
        OUT_OF_ORDER=false

        for p in $PERMS; do
            CUR="${p%%:*}"
            CUR="${CUR//$'\r'/}"
            PREV="${PREV//$'\r'/}"

            if [[ -z "$PREV" ]]; then
                PREV="$CUR"
                continue
            fi

            if [[ "$CUR" =~ ^[0-9]+$ && "$PREV" =~ ^[0-9]+$ ]]; then
                if (( CUR < PREV )); then
                    if [[ "$OUT_OF_ORDER" == false ]]; then
                        echo "Group: $GROUP"
                        echo "  ERROR - Permissions out of order:"
                        OUT_OF_ORDER=true
                    fi
                    echo "    $CUR appears after $PREV"
                fi
            fi

            PREV="$CUR"
        done

        [[ "$OUT_OF_ORDER" == true ]] && echo

    done < "$DEFAULT_FILE"

    exit 0
fi

########################################
# USER MODE
########################################

# Normalize username
USER_BASE="${USER_IN%@*}"
USER_UPPER=$(echo "$USER_BASE" | tr '[:lower:]' '[:upper:]')

# Match USER or USER@EMAIL
LINE=$(grep -iE "^${USER_UPPER}(@|;)" "$STAFF_FILE" | head -1)

if [[ -z "$LINE" ]]; then
    echo "User not found: $USER_IN"
    exit 1
fi

IFS=';' read -r USERNAME USERID PERMS FIRST LAST GROUP <<< "$LINE"

########################################
# Get Staff ID + Roles from staff.p
########################################

STAFF_ID="UNKNOWN"
ROLES="UNKNOWN"

FULL_NAME="$FIRST"

LAST_NAME=$(echo "$FULL_NAME" | cut -d',' -f1 | xargs)
FIRST_NAME=$(echo "$FULL_NAME" | cut -d',' -f2 | xargs)

MATCH_LINE=$(.dosu grep -i ";$FIRST_NAME;$LAST_NAME;" "$STAFFP_FILE" | head -1)

if [[ -n "$MATCH_LINE" ]]; then
    IFS=';' read -r RAW_ID FN LN REST <<< "$MATCH_LINE"
    STAFF_ID="staffid.$RAW_ID"

    ROLES=$(echo "$MATCH_LINE" | awk -F';' '
    {
        for (i=1; i<=NF; i++) {
            if ($i ~ /,/) {
                gsub(/^,|,$/, "", $i)
                print $i
                exit
            }
        }
    }')
fi

########################################
# Header Output
########################################

echo "Username: $USER_BASE"
echo "Staff ID: $STAFF_ID"
echo "Name: $FIRST $LAST"
echo "Group Permission: $GROUP"
echo "Role(s): $ROLES"

########################################
# ORDER CHECK
########################################

PERM_NUMS=()
for p in $PERMS; do
    PERM_NUMS+=("${p%%:*}")
done

OUT_OF_ORDER=false
ORDER_ERRORS=()
PREV=""

for CURRENT in "${PERM_NUMS[@]}"; do
    CURRENT="${CURRENT//$'\r'/}"
    PREV="${PREV//$'\r'/}"

    if [[ -z "$PREV" ]]; then
        PREV="$CURRENT"
        continue
    fi

    if [[ "$CURRENT" =~ ^[0-9]+$ && "$PREV" =~ ^[0-9]+$ ]]; then
        if (( CURRENT < PREV )); then
            OUT_OF_ORDER=true
            ORDER_ERRORS+=("$CURRENT appears after $PREV")
        fi
    fi

    PREV="$CURRENT"
done

########################################
# DEFAULT COMPARISON
########################################

DEFAULT_LINE=$(grep -i "^${GROUP};" "$DEFAULT_FILE" | head -1)

if [[ -z "$DEFAULT_LINE" ]]; then
    SKIP_COMPARE=true
else
    SKIP_COMPARE=false
fi

if [[ "$SKIP_COMPARE" == false ]]; then

    IFS=';' read -r DEF_GROUP DEF_PERMS <<< "$DEFAULT_LINE"

    declare -A USER_MAP DEF_MAP

    for p in $PERMS; do
        USER_MAP["${p%%:*}"]="${p##*:}"
    done

    for p in $DEF_PERMS; do
        DEF_MAP["${p%%:*}"]="${p##*:}"
    done

    MISSING=false
    EXTRA=false
    MISMATCH=false

    MISSING_LIST=()
    EXTRA_LIST=()
    MISMATCH_LIST=()

    for NUM in "${!DEF_MAP[@]}"; do
        if [[ -z "${USER_MAP[$NUM]}" ]]; then
            MISSING=true
            MISSING_LIST+=("$NUM:${DEF_MAP[$NUM]}")
        elif [[ "${USER_MAP[$NUM]}" != "${DEF_MAP[$NUM]}" ]]; then
            MISMATCH=true
            MISMATCH_LIST+=("$NUM:${DEF_MAP[$NUM]}")
        fi
    done

    for NUM in "${!USER_MAP[@]}"; do
        if [[ -z "${DEF_MAP[$NUM]}" ]]; then
            EXTRA=true
            EXTRA_LIST+=("$NUM:${USER_MAP[$NUM]}")
        fi
    done
fi

########################################
# CONFIG STATUS (FINAL CLEAN VERSION)
########################################

echo "Config Status:"

# Ordering
if [[ "$OUT_OF_ORDER" == false ]]; then
    echo "  Permissions are in order"
else
    echo "  ERROR - Permissions are out of order"
fi

# Comparison
if [[ "$SKIP_COMPARE" == true ]]; then
    echo "  WARNING - Group '$GROUP' not defined in default_perms.m (comparison skipped)"
elif ! $MISSING && ! $EXTRA && ! $MISMATCH; then
    echo "  Permissions match default_perms.m file"
else
    echo "  ERROR - Permissions DO NOT match default_perms.m file"
fi

echo

########################################
# ORDER DETAILS
########################################

if [[ "$OUT_OF_ORDER" == true ]]; then
    echo "Out of order entries detected:"
    for err in "${ORDER_ERRORS[@]}"; do
        echo "  $err"
    done
    echo
fi

########################################
# DIFFERENCE REPORTING
########################################

if [[ "$SKIP_COMPARE" == false && $MISSING == true ]]; then
    echo "User is missing:"
    for entry in "${MISSING_LIST[@]}"; do
        format_output "${entry%%:*}" "${entry##*:}"
    done
    echo
fi

if [[ "$SKIP_COMPARE" == false && $EXTRA == true ]]; then
    echo "User should not have:"
    for entry in "${EXTRA_LIST[@]}"; do
        format_output "${entry%%:*}" "${entry##*:}"
    done
    echo
fi

if [[ "$SKIP_COMPARE" == false && $MISMATCH == true ]]; then
    echo "User should have Read/Write correction for:"
    for entry in "${MISMATCH_LIST[@]}"; do
        format_output "${entry%%:*}" "${entry##*:}"
    done
    echo
fi

########################################
# CURRENT PERMISSIONS
########################################

echo "Permissions Granted:"
printf "%-12s %-30s %-10s\n" "Appli Num" "Application" "Permissions"
printf "%-12s %-30s %-10s\n" "-----------" "------------------------------" "-----------"

for p in $PERMS; do
    format_output "${p%%:*}" "${p##*:}"
done
