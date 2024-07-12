#!/usr/bin/env bash

source tests/base.sh

testdir="testdir"
filename="test.md"
filepath="${testdir}/${filename}"


echo ">>> $0 >>> Creating new note $filepath"
echo -n "content" | "$script" edit "$filepath" 1>/dev/null


echo ">>> $0 >>> drafting $filepath"
"$script" draft "$filepath" 1>/dev/null

echo ">>> $0 >>> Test list draft correct dir"
[[ "$("$script" ls draft)" = "$testdir" ]]

echo ">>> $0 >>> Test list draft correct file"
[[ "$("$script" ls "draft/${testdir}")" = "$filename" ]]


echo ">>> $0 >>> undrafting $filepath"
"$script" undraft "$filepath" 1>/dev/null

echo ">>> $0 >>> Test list draft empty dir"
[[ "$("$script" ls "draft/${testdir}")" = "" ]]

echo ">>> $0 >>> Test list root correct dir and file"
[[ "$("$script" ls "${testdir}")" = "$filename" ]]