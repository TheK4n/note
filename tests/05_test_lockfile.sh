#!/usr/bin/env bash


source tests/base.sh

set -m

echo ">>> $0 >>> Test edit command locks other edit command"
"$script" edit somenote.md &
sleep 1
echo "." | { ! "$script" edit somenote.md 1>/dev/null; }
kill %1


echo ">>> $0 >>> Test edit command not locks show command"
echo "note2" | "$script" edit note2.md 1>/dev/null
"$script" edit somenote.md 1>/dev/null &
sleep 1
"$script" show note2.md 1>/dev/null
kill %1