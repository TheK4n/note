#!/bin/sh

. tests/base.sh

filename="test2.md"


echo ">>> $0 >>> Creating new note $filename"
echo "sdfasdff" | "$script" edit "$filename" 1>/dev/null

echo ">>> $0 >>> Deleting note $filename"
"$script" rm "$filename"

echo ">>> $0 >>> Test storage is empty"
[ -z "$("$script" ls)" ]