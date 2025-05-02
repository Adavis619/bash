#!/bin/bash

. /etc/.profile
#set -xv

# Usage helper
tshow_usage() {
    echo ""
    echo "Usage:"
    echo "  .dosu asgr [-c] [-f] <file_or_dir> [server]"
    echo "    -c    run CTImport (check-in) after rsync"
    echo "    -f    treat the target as a full path instead of syncing from current directory"
    echo "    server (optional) limits sync to that single host"
    echo ""
    exit 1
}

if [ $# -eq 0 ]; then
    show_usage
fi

# Parse flags
CHECKIN=false
FULLPATH=false
while getopts "cf" opt; do
    case "$opt" in
        c) CHECKIN=true ;;  # run CTImport after rsync
        f) FULLPATH=true ;; # use full path logic
        *) show_usage ;;
    esac
done
shift $((OPTIND -1))

# Validate remaining args
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    show_usage
fi

TARGET="$1"

# Determine rsync source and remote destination path
if $FULLPATH; then
    if [ -d "$TARGET" ]; then
        # Directory: preserve trailing slash
        DIRNAME="${TARGET%/}"
        RSYNC_SRC="$DIRNAME/"
        RSYNC_DEST="$DIRNAME/"
    elif [ -f "$TARGET" ]; then
        DIRNAME="$(dirname "$TARGET")"
        BASEFILE="$(basename "$TARGET")"
        RSYNC_SRC="$DIRNAME/$BASEFILE"
        RSYNC_DEST="$DIRNAME/"
    else
        echo "ERROR: $TARGET is not a valid file or directory" >&2
        exit 1
    fi
else
    # Original behavior: sync from current working directory
    FN="${TARGET#./}"
    RSYNC_SRC="$FN"
    RSYNC_DEST="$(pwd)/"
fi

# Build list of target servers
if [ $# -eq 2 ]; then
    SERVERS=("$2")
else
    IFS=$'\n' read -r -d '' -a SERVERS < <(printf '%s\n' "${SYSLIST//$HOST/}" && printf '\0')
fi

# Loop through each server
for rserv in "${SERVERS[@]}"; do
    # Auto-create remote directory
    .dosu ssh -n "$rserv" "mkdir -p '$RSYNC_DEST'"
    
    # Perform rsync
    .dosu rsync -azv -- "$RSYNC_SRC" "$rserv:$RSYNC_DEST" || {
        echo "ERROR: rsync to $rserv failed" >&2
        exit 1
    }

    # Run CTImport if requested
    if $CHECKIN; then
        .dosu CTImport -f -- "$RSYNC_SRC" || {
            echo "ERROR: CTImport on $rserv failed" >&2
            exit 1
        }
    fi
done

exit 0
