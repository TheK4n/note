#!/bin/sh

. tests/base.sh

content="# new note"
filename="test.md"

echo ">>> $0 >>> Creating new note $filename"
echo "$content" | "$script" edit "$filename" 1>/dev/null

echo ">>> $0 >>> Test list correct files"
[ "$("$script" ls)" = "$filename" ]

echo ">>> $0 >>> Test file contain correct content"
[ "$("$script" show "$filename")" = "$content" ]