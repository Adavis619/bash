#!/bin/bash

# asg_deIdent.sh
# Automates patient record de-identification from Source to Destination via Intermediate server

# Usage: ./asg_deIdent.sh <SourceServer> <IntermediateServer> <DestinationServer> <PatientRecord>
# Example: ./asg_deIdent.sh vfenc1 comsupc asgcore1 vol8/p83887228

set -euo pipefail

# ANSI color codes
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NC='\e[0m'

# Input validation
if [ "$#" -ne 4 ]; then
    echo -e "${RED}Usage: $0 <SourceServer> <IntermediateServer> <DestinationServer> <PatientRecord>${NC}"
    exit 1
fi

# Arguments
SRC="$1"
INT="$2"
DST="$3"
RECORD="$4"
PATID=$(basename "$RECORD" | cut -c2-)   # Extract numeric part from p83887228 => 83887228
TFILE="T${PATID}.z"
LOG="asg_deIdent_$(date +%Y%m%d_%H%M%S).log"

# Start logging
exec > >(tee "$LOG") 2>&1

echo -e "${YELLOW}=== Starting de-identification process ===${NC}"
echo -e "${GREEN}Source: $SRC | Intermediate: $INT (this host) | Destination: $DST${NC}"
echo -e "${GREEN}Patient Record: $RECORD | Tarball: $TFILE${NC}"
echo "Log: $LOG"
echo "Timestamp: $(date)"
echo

# Step 1: Tar up the patient record on the Source Server
echo -e "${YELLOW}==> Tarring $RECORD on $SRC...${NC}"
ssh "$SRC" "cd /vfenc/vfenc/run && .dosu tar -czvf /usr/tmp/$TFILE $RECORD"

# Step 2: Transfer tarball to Intermediate Server, then to Destination
echo -e "${YELLOW}==> Copying tarball from $SRC to $INT...${NC}"
scp "$SRC:/usr/tmp/$TFILE" .

echo -e "${YELLOW}==> Forwarding tarball from $INT to $DST...${NC}"
scp "$TFILE" "$DST:/usr/tmp"

# Step 3: Run de-identification on Destination Server
echo -e "${YELLOW}==> Performing de-identification on $DST...${NC}"
ssh "$DST" bash -c "'
set -e
echo -e \"\n=== [ $DST ] De-identification session started ===\"

cd /usr/tmp
.dosu mkdir -p /usr/tmp/xidpat || true
.dosu chmod 777 /usr/tmp/xidpat
chmod 777 $TFILE

TFILE=$TFILE
TVOL=$RECORD

# Extract and de-identify
.dosu tar xvfz \$TFILE
.dosu deIdent -p /usr/tmp/\$TVOL -c \$CCSYSDIR/deIdent.rcf -s \$CCSYSDIR/deIdent.staff -l xidlog -d debug

# Repack and cleanup
cd /usr/tmp/xidpat
.dosu tar cvfz /usr/tmp/\$TFILE \$TVOL
.dosu rm -r /usr/tmp/xidpat/vol*
.dosu rm -r /usr/tmp/\$TVOL
.dosu rm /usr/tmp/xidpat/vol*

# Add de-identified patient
cd /san/san/run
.dosu tar xvfz /usr/tmp/\$TFILE
.dosu addpat \$TVOL
PATID=$PATID
CAMPUS=\$SITE
.dosu cql -S -iwritecampus.scm

# Confirm record
D \$TVOL
echo -e \"=== [ $DST ] De-identification complete ===\"
'"

echo -e "${GREEN}==> All done! De-identified patient record added.${NC}"
echo -e "${GREEN}Check the full log at: $LOG${NC}"