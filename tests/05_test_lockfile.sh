#!/usr/bin/env bash

set -e
set -m

export EDITOR=tee
export CAT=cat

script="./note.sh"

echo ">>> $0 >>> Test edit command locks other edit command"
"$script" edit somenote.md &
sleep 1
if echo "." | "$script" edit somenote.md; then false; else true; fi
kill %1


echo ">>> $0 >>> Test edit command not locks show command"
echo "note2" | "$script" edit note2.md
"$script" edit somenote.md &
sleep 1
"$script" show note2.md
kill %1
