#!/bin/bash
. /etc/.profile
#set -xv

: '
1. Purpose: To numerically reorder or renumber files. Intended for list.fs or list.default files.
            This script can process a file in two ways:
            In the default (renumber) mode, non-commented lines are kept in their original order and a lines list number may be modified.
            In reorder mode (with the "-r" flag), numeric lines are re-ordered based on their original numeric assignment. The list number of the line is not changed, the line may just be moved.
            In both modes, commented out lines are moved to the bottom of the file.
            By default, the file name must start with "list.".
            The "-a" flag allows any file name.
2. Description: run "./asg_listorder.sh [-a] [-r] inputfile"
3. Author: Anthony Davis
4. Date: 04/02/2025
5. Usage: ./asg_listorder.sh [-a] [-r] inputfile
'

# Define color codes
YELLOW='\e[33m'
GREEN='\e[32m'
RED='\e[31m'
NC='\e[0m'

# Setup the optional flags to enable modes:
# -a (allow any file)
# -r (reorder mode)
allowAny=0
mode="renumber"
while [[ "$1" == -* ]]; do
    case "$1" in
        -a)
            allowAny=1
            shift
            ;;
        -r)
            mode="reorder"
            shift
            ;;
        *)
            echo -e "${RED}Unknown flag:${RED} $1"
            echo -e "${YELLOW}Usage: $0 [-a] [-r] inputfile${NC}
By default, this script ${YELLOW}RENUMBERS${NC} and processes list files. For any other file, use the [-a] flag.
To ${YELLOW}REORDER${NC} and retain each lines list number, use the [-r] flag."
            exit 1
            ;;
    esac
done

if [ "$#" -lt 1 ]; then
    echo -e "${YELLOW}Usage: $0 [-a] [-r] inputfile${NC}
By default, this script ${YELLOW}RENUMBERS${NC} and processes list files. For any other file, use the [-a] flag.
To ${YELLOW}REORDER${NC} and retain each lines list number, use the [-r] flag."
    exit 1
fi

# Check for the inputfile
inputfile="$1"
if [ ! -f "$inputfile" ]; then
    echo -e "${RED}Error:${NC} File '$inputfile' not found."
    exit 1
fi

# Check to see that list file, env.cf, or unittype was provided by default
basename=$(basename "$inputfile")
fileType="list"
if [[ $basename == env.cf ]]; then
    fileType="env"
elif [[ $basename == unittype ]]; then
    fileType="unittype"
elif [[ $basename != list.* ]] && [ $allowAny -ne 1 ]; then
    echo -e "${RED}Error:${NC} File name must start with 'list.', be 'env.cf', be 'unittype', or use the -a flag."
    exit 1
fi

# Reorder mode only applies to list files
if [[ "$mode" == "reorder" ]] && [[ "$fileType" == "env" || "$fileType" == "unittype" ]]; then
    echo -e "${RED}Error:${NC} Reorder mode (-r) only applies to list files."
    echo -e "${YELLOW}Files 'env.cf' and 'unittype' only support renumbering.${NC}"
    exit 1
fi

# Create a backup copy of the original file.
backupfile="${inputfile}.reorder.bak"
cp "$inputfile" "$backupfile"
echo -e "${YELLOW}Backup created:${NC} $backupfile"

# Create a temporary file for file processing.
temp=$(mktemp)

# Proceed with default renumbering:

# Determine which mode to run in. Default or reorder.
awk -v mode="$mode" -v fileType="$fileType" '
{
# Skip empty lines (lines with only whitespace or completely empty)
if ($0 ~ /^[[:space:]]*$/) {
    next
}
 
# Handle env.cf files
if (fileType == "env") {
    # Just store all lines in order (including comments)
    allLines[++lineCount] = $0
    next
}
 
# Handle unittype files
if (fileType == "unittype") {
    # Store all lines in order (including comments)
    allLines[++lineCount] = $0
    next
}
 
# Original list file processing below
# Check for commented out lines and add to commented array
# If not commented out then add to the notCommented array
if ($0 ~ /^[[:space:]]*#/) {
        commented[++nc] = $0
    } else {
        notCommented[++nn] = $0
        # If the line starts with a number then add it to the orderedLine array
        if ($0 ~ /^[[:space:]]*[0-9]+/) {
            orderedLine[nn] = 1
            # If the reorder mode is chosen use match to find a numeric pattern and then store it into the array toReNum
            if (mode == "reorder") {
                if (match($0, /^[[:space:]]*([0-9]+)/, toReNum)) {
                    # Convert the toReNum arry into an incremented list stored in the array numVal
                    numVal[++nr] = toReNum[1] + 0
                    # nr keeps count of the processed lines to renumber
                    numeric[nr] = $0
                }
            }
        } else {
            # nn keeps count of the non-commented out lines processed above
            orderedLine[nn] = 0
        }
    }
}
END {
# Handle env.cf file renumbering
if (fileType == "env") {
    counter = 1
    for (i = 1; i <= lineCount; i++) {
        line = allLines[i]
        # Renumber lines with #N pattern, leave comments as-is
        if (line ~ /^[^#].*#[0-9]+/) {
            # Use gensub to replace #N with the sequential counter
            newLine = gensub(/(.*#)[0-9]+(.*)/, "\\1" counter "\\2", 1, line)
            print newLine
            counter++
        } else {
            # Print comments and other lines unchanged
            print line
        }
    }
    next
}
 
# Handle unittype file renumbering
if (fileType == "unittype") {
    counter = 0
    for (i = 1; i <= lineCount; i++) {
        line = allLines[i]
        # Renumber non-comment lines with []\N pattern at the end
        if (line !~ /^[[:space:]]*#/) {
            # Use gensub to replace the last []N with the sequential counter
            newLine = gensub(/(\[\])[0-9]+[[:space:]]*$/, "\\1" counter, 1, line)
            print newLine
            counter++
        } else {
            # Print comments unchanged
            print line
        }
    }
    next
}
 
# Original list file processing below
# Proceed with reording if that option is chosen:
if (mode == "reorder") {
        # Sort the collected numbered lines and add to the sorted array
        for (i = 1; i <= nr; i++) {
            sorted[i] = i
        }
        # If a line with a number in the sorted i array is greater than one in the sorted j array then they are swapped
        for (i = 1; i <= nr; i++) {
            for (j = i+1; j <= nr; j++) {
                if (numVal[sorted[i]] > numVal[sorted[j]]) {
                    tmp = sorted[i]
                    sorted[i] = sorted[j]
                    sorted[j] = tmp
                }
            }
        }
        numericIndex = 1
    } else {
        counter = 1
    }
    # Process non-commented lines in their original order.
    for (i = 1; i <= nn; i++) {
        line = notCommented[i]
        if (orderedLine[i] == 1) {
            # Print from the sorted array in numerical order counted by numericIndex
            if (mode == "reorder") {
                print numeric[sorted[numericIndex]]
                numericIndex++
            } else {
                # gensub searches a target string for matches
                # In this case used to change the next line to be printed with the next number in counter
                newLine = gensub(/^([[:space:]]*)[0-9]+/, "\\1" counter, 1, line)
                print newLine
                counter++
            }
        } else {
            # If a line is not commented out or does not start with a number just print it as it was
            print line
        }
    }
    # Print the commented out lines underneath the non-commented out lines
    for (i = 1; i <= nc; i++) {
        print commented[i]
    }
}
' "$inputfile" > "$temp"

mv "$temp" "$inputfile"
.dosu chmod 750 "$inputfile"
.dosu asgr "$inputfile"
diff "$inputfile" "$backupfile"
