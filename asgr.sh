#!/bin/bash

. /etc/.profile
#set -xv

: '
1. Purpose: To rsync file/directory to redundant servers faster than R-copy
2. Description: run "asgr <filename>" for "asgr <directory name>.  This script is available in $LBIN in all DoD servers.
                This is owner specific.  Run as ".dosu asgr .." otherwise the file/directory will be owned by you in redundant servers
3. Author: 
4. Date: 
4. Usage: asgr <filename>
'

if [ $# == 0 ]; then
    echo ""
    echo "Usage:"
    echo "...To push file or directory to all redundant servers..."
    echo ".dosu asgr [FILE]"
    echo ".dosu asgr [FULL PATH OF A DIRECTORY]"
    echo "...To push file or directory to one specific redundant server..."
    echo ".dosu asgr [FILE] server#"
    echo ".dosu asgr [FULL PATH OF A DIRECTORY] server#"
    echo ""
    exit 1;
fi

while getopts c: option
do
    case "${option}"
        in
        c) if [ $# -gt 2 ]; then
    FN=`echo $2 | sed  's/^\.\///'`
    RSERVER=$3
    .dosu rsync -azv $FN $RSERVER:`pwd`
    .dosu CTImport -f $FN
    exit 1;
else
    FN=`echo $2 | sed  's/^\.\///'`
    RSERVER=`printf '%s\n' "${SYSLIST//$HOST/}"`
    for rserv in `echo $RSERVER`
    do
        .dosu rsync -azv $FN $rserv:`pwd`
        .dosu CTImport -f $FN
    done
fi
esac


# For Rsync Dir, we can use this:
for rserv in `echo $RSERVER`
do
.dosu rsync -azv $dirname/ $rserv:$dirname
done

# for Rsync file with full path, we'll probably need dirname and basename utils
e.g.,
basedir=$(dirname `echo $1`)
basefile=$(basename `echo $1`)
exit

done

if [ $# -gt 1 ]; then
    FN=`echo $1 | sed  's/^\.\///'`
    RSERVER=$2
    .dosu rsync -azv $FN $RSERVER:`pwd`
    exit 1;
else
    FN=`echo $1 | sed  's/^\.\///'`
    RSERVER=`printf '%s\n' "${SYSLIST//$HOST/}"`
    for rserv in `echo $RSERVER`
    do
        .dosu rsync -azv $FN $rserv:`pwd`
    done
fi

exit

asgr was written based on assumption that the file will be remotely sync'd from pwd, as "R" script does.

I would like to retain what asgr is doing now but add a flag "-f" so that it takes full path dir/file names

e.g.,

.dosu asgr -f $CCRUN/conf/webess/cpoe2/categories
.dosu asgr -f $CCRUN/conf/webess/screens
