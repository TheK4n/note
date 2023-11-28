#!/usr/bin/env bash

set -e

export EDITOR=tee
export CAT=cat

script="./note.sh"
filename="test2.md"


echo ">>> $0 >>> Creating new note $filename"
echo -n "sdfasdff" | "$script" edit "$filename" 1>/dev/null

echo ">>> $0 >>> Deleting note $filename"
"$script" rm "$filename"

echo ">>> $0 >>> Test storage is empty"
[ -z "$("$script" ls)" ]
