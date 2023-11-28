#!/usr/bin/env bash

set -e

export EDITOR=tee
export CAT=cat

script="./note.sh"
subdir="someDir"
storage="$($script show_storage)"

echo ">>> $0 >>> Test creating dir $subdir"
"$script" mkdir "$subdir"
test -d "$storage/$subdir"


echo ">>> $0 >>> Test removing empty dir"
"$script" rm "$subdir" || true ######
[ ! -e "$storage/$subdir" ]


echo ">>> $0 >>> Test command 'edit' with path creating directory"
echo "." | "$script" edit "$subdir/test.md"
test -d "$storage/$subdir"


echo ">>> $0 >>> Test removing not empty dir"
"$script" rm "$subdir"
[ ! -e "$storage/$subdir" ]


echo ">>> $0 >>> Test writing blank note with path not creating subdir"
EDITOR=true "$script" edit "$subdir/test.md"
[ ! -e "$storage/$subdir" ]


echo ">>> $0 >>> Test writing blank note with path in non empty subdir not deleting subdir"
echo "." | "$script" edit "$subdir/test.md"
EDITOR=true "$script" edit "$subdir/test2.md"
[ -d "$storage/$subdir" ]
