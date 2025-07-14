#!/bin/bash
. /etc/.profile
#set -xv

: '
1. Purpose: To create new ALPHA, RT, or PGOLD unit and environments.
2. Description: run "asg_mkTerm.sh"
3. Author: Anthony Davis
4. Date: 04/01/2025
5. Usage: asg_mkTerm.sh -a # For ALPHA versions (e.g. asg_mkTerm.sh -a 36)
          asg_mkTerm.sh -p # For PGOLD versions (e.g. asg_mkTerm.sh -p 36)
          asg_mkTerm.sh -r # For RT versions (e.g. asg_mkTerm.sh -r 36)
'


# Define color codes
YELLOW='\e[33m'
GREEN='\e[32m'
RED='\e[31m'
NC='\e[0m'

# Check environment and version
if [ $# -ne 2 ]; then
    echo "Usage: $0 -a < version> | -p < version> | -r < version>"
    exit 1
fi

flag="$1"
version="$2"

# Version error check
if ! [[ $version =~ ^[0-9]+$ ]]; then
    echo "Error: Version must be a positive integer."
    exit 1
fi

case "$flag" in
    -a)
        # ALPHA
        new_version="$version"
        old_version=$(( version - 1 ))
        new_alpha="ALPHA-$new_version"
        old_alpha="ALPHA-$old_version"

        echo -e "${YELLOW}Creating new ALPHA version: $new_alpha ${NC}"

        if [ -z "$CCSYSDIR" ]; then
            echo "Error: CCSYSDIR environment variable is not set."
            exit 1
        fi

        cd "$CCSYSDIR" || { echo "Cannot change directory to $CCSYSDIR/vad/vad/run"; exit 1; }
        .dosu Rmkdir "E_${new_alpha}"
        .dosu chmod 777 "E_${new_alpha}"

        cd "E_${new_alpha}" || { echo "Cannot change directory to E_${new_alpha}"; exit 1; }
        .dosu e env
        .dosu asgr env
        .dosu CTImport -f env

        cd "$CCSYSDIR" || exit 1

        echo -e "${YELLOW}Update env.cf with new unit and environment.${NC}"
bu env.cf
.dosu e env.cf
.dosu CTImport -f env.cf
        echo -e "${YELLOW}Update SystemConfig with new unit and hold bed.${NC}"
bu SystemConfig
.dosu e SystemConfig
.dosu Rmake bedcf
.dosu CTImport -f SystemConfig
.dosu Rload
        echo -e "${YELLOW}Update unittype file with new unit and environment.${NC}"
        cd $CCRUN/conf/webess/visit || { echo "Cannot change directory to $CCRUN/conf/webess/visit"; exit 1; }
        bu unittype
        .dosu e unittype
        .dosu RESTART_YCQLD
        echo -e "${YELLOW}Updating screens files.${NC}"
        cd $CCRUN/conf/webess/screens || { echo "Cannot change directory to $CCRUN/conf/webess/screens"; exit 1; }
        for name in ${old_alpha}*; do
            .dosu cp "$name" "${new_alpha}${name#${old_alpha}}"
        done

        .dosu cp "list.default.${old_alpha}" "list.default.${new_alpha}"
        .dosu cp "list.fs.${old_alpha}" "list.fs.${new_alpha}"
        .dosu cp "mvisit2.conf.${old_alpha}" "mvisit2.conf.${new_alpha}"

        for i in ${new_alpha}*; do
            .dosu sed -i "s/${old_alpha}/${new_alpha}/g" "$i"
        done

        for i in *${new_alpha}; do
            .dosu sed -i "s/${old_alpha}/${new_alpha}/g" "$i"
        done

        echo -e "${YELLOW}Updating flowsheet files: general, formulas, fs_sections, items.${NC}"
        # Update flowsheets (general, formulas, fs_sections, items)
        for dir in general formulas fs_sections items; do
            cd "$CCRUN/conf/webess/flowsheets/${dir}" || { echo "Cannot change directory to $CCRUN/conf/webess/flowsheets/${dir}"; exit 1; }
            for name in ${old_alpha}*; do
                .dosu cp "$name" "${new_alpha}${name#${old_alpha}}"
            done
            for i in ${new_alpha}*; do
                .dosu sed -i "s/${old_alpha}/${new_alpha}/g" "$i"
            done
        done

        # Update choices
        echo -e "Updating choicelist directories and files. This may take a few minutes."
        cd $CCRUN/conf/webess/choices || { echo "Cannot change directory to $CCRUN/conf/webess/choices"; exit 1; }

        TOTAL_FILES=$(ls "$old_alpha"* 2>/dev/null | wc -l)
        COUNT=0

        for name in ${old_alpha}*; do
                COUNT=$((COUNT + 1))
                echo -ne "${YELLOW}Processing file $COUNT of $TOTAL_FILES...\r${NC}"
                .dosu cp -r "$name" "${new_alpha}${name#${old_alpha}}"
                done

        for i in ${new_alpha}*; do
            cd "$i" || continue
            .dosu rm list.db
            b
        done

                echo -e "\nChoicelist files complete."

                echo " ($new_alpha) created."
        ;;
    -p)
        # PGOLD
        PGOLD_V="PGOLD-$version"
        PRE_GOLD="PGOLD-$(( version - 1 ))"

        echo "Creating new PGOLD version: $PGOLD_V "

        cd /usr/tmp/ || { echo "Cannot change directory to /usr/tmp"; exit 1; }
        .dosu Rmkdir "$PGOLD_V"
        .dosu chmod 777 "$PGOLD_V"

        cd "$CCSYSDIR" || exit 1
        .dosu Rmkdir "E_$PGOLD_V"
        .dosu chmod 777 "E_$PGOLD_V"

        cd "E_$PGOLD_V" || { echo "Cannot change directory to E_$PGOLD_V"; exit 1; }
        .dosu e env
        .dosu asgr env
        .dosu CTImport -f env

        cd "$CCSYSDIR" || exit 1

bu env.cf
.dosu e env.cf
.dosu CTImport -f env.cf
bu SystemConfig
.dosu e SystemConfig
.dosu Rmake bedcf
.dosu CTImport -f SystemConfig
.dosu Rload

        # Update unittype
        cd "$CCRUN/conf/webess/visit" || { echo "Cannot change directory to $CCRUN/conf/webess/visit"; exit 1; }
        bu unittype
        .dosu e unittype
        .dosu RESTART_YCQLD
        .dosu itMapGen remx
        .dosu itMapGen
        .dosu RESTART_ADTD

        # Update screens
        cd "$CCRUN/conf/webess/screens" || { echo "Cannot change directory to $CCRUN/conf/webess/screens"; exit 1; }
        for name in "$PRE_GOLD"*; do
            .dosu cp "$name" "$PGOLD_V${name#$PRE_GOLD}"
        done

        for i in "$PGOLD_V"*; do
            .dosu sed -i "s/${PRE_GOLD}/${PGOLD_V}/g" "$i"
        done

        .dosu cp "list.default.$PRE_GOLD" "list.default.$PGOLD_V"
        .dosu cp "list.fs.$PRE_GOLD" "list.fs.$PGOLD_V"
        .dosu cp "mvisit2.conf.$PRE_GOLD" "mvisit2.conf.$PGOLD_V"
        .dosu cp "list.dashboards.$PRE_GOLD" "list.dashboards.$PGOLD_V"

        for i in *"$PGOLD_V"; do
            .dosu sed -i "s/${PRE_GOLD}/${PGOLD_V}/g" "$i"
        done

        # Update flowsheets - general, formulas, fs_sections, items
        cd "$CCRUN/conf/webess/flowsheets/general" || { echo "Cannot change directory to $CCRUN/conf/webess/flowsheets/general"; exit 1; }
        for name in "$PRE_GOLD"*; do
            .dosu cp -r "$name" "$PGOLD_V${name#$PRE_GOLD}"
        done

        for i in "$PGOLD_V"*; do
            .dosu sed -i "s/${PRE_GOLD}/${PGOLD_V}/g" "$i"
        done

        cd "$CCRUN/conf/webess/flowsheets/formulas" || { echo "Cannot change directory to $CCRUN/conf/webess/flowsheets/formulas"; exit 1; }
        for name in "$PRE_GOLD"*; do
            .dosu cp "$name" "$PGOLD_V${name#$PRE_GOLD}"
        done

        for i in "$PGOLD_V"*; do
            .dosu sed -i "s/${PRE_GOLD}/${PGOLD_V}/g" "$i"
        done

        cd "$CCRUN/conf/webess/flowsheets/fs_sections" || { echo "Cannot change directory to $CCRUN/conf/webess/flowsheets/fs_sections"; exit 1; }
        for name in "$PRE_GOLD"*; do
            .dosu cp "$name" "$PGOLD_V${name#$PRE_GOLD}"
        done

        for i in "$PGOLD_V"*; do
            .dosu sed -i "s/${PRE_GOLD}/${PGOLD_V}/g" "$i"
        done

        cd "$CCRUN/conf/webess/flowsheets/items" || { echo "Cannot change directory to $CCRUN/conf/webess/flowsheets/items"; exit 1; }
        for name in "$PRE_GOLD"*; do
            .dosu cp "$name" "$PGOLD_V${name#$PRE_GOLD}"
        done

        for i in "$PGOLD_V"*; do
            .dosu sed -i "s/${PRE_GOLD}/${PGOLD_V}/g" "$i"
        done

        # Update choices
        echo -e "Updating choicelist directories and files. This may take a few minutes."
                cd "$CCRUN/conf/webess/choices" || { echo "Cannot change directory to $CCRUN/conf/webess/choices"; exit 1; }

                TOTAL_FILES=$(ls "$PRE_GOLD"* 2>/dev/null | wc -l)
                COUNT=0

                for name in "$PRE_GOLD"*; do
                COUNT=$((COUNT + 1))
                echo -ne "${YELLOW}Processing file $COUNT of $TOTAL_FILES...\r${NC}"
                .dosu cp -r "$name" "$PGOLD_V${name#$PRE_GOLD}"
                done

                echo -e "\nChoicelist files complete."

        for name in "$PRE_GOLD"vagold_pacu_VASCULARDEVICES.conf*; do
            .dosu cp -r "$name" "$PGOLD_V${name#$PRE_GOLD}"
        done

        for name in "$PRE_GOLD"vagold_pacu_*.conf*; do
            .dosu cp -r "$name" "$PGOLD_V${name#$PRE_GOLD}"
        done

        # Copy choicedesc
        cd "$CCSYSDIR/E_$PRE_GOLD" || { echo "Cannot change directory to $CCSYSDIR/E_$PRE_GOLD"; exit 1; }
        .dosu cp choicedesc "$CCSYSDIR/E_$PGOLD_V/choicedesc"

        cd "$CCSYSDIR/E_$PGOLD_V" || { echo "Cannot change directory to $CCSYSDIR/E_$PGOLD_V"; exit 1; }
        .dosu CTImport -f choicedesc

        echo "($PGOLD_V) created."
        ;;
    -r)
        # RT branch

        new_rt="RT-$version"
        pre_rt="RT-$(( version - 1 ))"

        # For certain flowsheets items, update ALPHA references.
        old_alpha_ref="ALPHA-$(( version - 1 ))"
        new_alpha_ref="ALPHA-$version"

        echo "Creating new RT version: $new_rt "

        if [ -z "$CCSYSDIR" ]; then
            echo "Error: CCSYSDIR environment variable is not set."
            exit 1
        fi

        # Create new RT environment
        cd "$CCSYSDIR/vad/vad/run" || { echo "Cannot change directory to $CCSYSDIR/vad/vad/run"; exit 1; }
        .dosu Rmkdir "E_${new_rt}"
        .dosu chmod 777 "E_${new_rt}"

        cd "E_${new_rt}" || { echo "Cannot change directory to E_${new_rt}"; exit 1; }
        .dosu e env
        .dosu asgr env
        .dosu CTImport -f env

        cd "$CCSYSDIR" || exit 1

bu env.cf
.dosu e env.cf
.dosu CTImport -f env.cf
bu SystemConfig
.dosu e SystemConfig
.dosu Rmake bedcf
.dosu CTImport -f SystemConfig
.dosu Rload

        # Update unittype
        cd $CCRUN/conf/webess/visit || { echo "Cannot change directory to /vad/conf/webess/visit"; exit 1; }
        bu unittype
        .dosu e unittype
        .dosu RESTART_YCQLD

        # Update screens
        cd $CCRUN/conf/webess/screens || { echo "Cannot change directory to /vad/conf/webess/screens"; exit 1; }
        for name in ${pre_rt}*; do
            .dosu cp "$name" "${new_rt}${name#${pre_rt}}"
        done

        .dosu cp "list.default.${pre_rt}" "list.default.${new_rt}"
        .dosu cp "list.fs.${pre_rt}" "list.fs.${new_rt}"
        .dosu cp "mvisit2.conf.${pre_rt}" "mvisit2.conf.${new_rt}"

        for i in ${new_rt}*; do
            .dosu sed -i "s/${pre_rt}/${new_rt}/g" "$i"
        done

        # Update flowsheets (general, formulas, fs_sections, items)
        for dir in general formulas fs_sections items; do
            cd "$CCRUN/conf/webess/flowsheets/${dir}" || { echo "Cannot change directory to $CCRUN/conf/webess/flowsheets/${dir}"; exit 1; }
            for name in ${pre_rt}*; do
                .dosu cp "$name" "${new_rt}${name#${pre_rt}}"
            done
            for i in ${new_rt}*; do
                .dosu sed -i "s/${pre_rt}/${new_rt}/g" "$i"
            done
        done

        # Update specific flowsheets items files for ALPHA references
        cd $CCRUN/conf/webess/flowsheets/items || { echo "Cannot change directory to $CCRUN/conf/webess/flowsheets/items"; exit 1; }
        for i in uvent_rt_ventwean.conf uvent_rt_labs.conf uvent_rt_bedsidemonitor.conf 5ACCU_vagold_rt_ASSESSMENT2.conf 5ACCU_vagold_rt_TREATMENT2.conf; do
            .dosu sed -i "s/${old_alpha_ref}/${new_alpha_ref}/g" "$i"
        done

        # Update choices
        cd $CCRUN/conf/webess/choices || { echo "Cannot change directory to $CCRUN/conf/webess/choices"; exit 1; }
        for name in ${pre_rt}*; do
            .dosu cp -r "$name" "${new_rt}${name#${pre_rt}}"
        done

        for i in ${new_rt}*; do
            cd "$i" || continue
            .dosu rm list.db
            b
        done

        echo "($new_rt) created."
        ;;
    *)
        echo "Invalid flag. Use -a for ALPHA, -p for PGOLD, or -r for RT."
        exit 1
        ;;
esac
