#!/bin/sh


. tests/base.sh

subdir="someDir"
storage="$($script --prefix)"

echo ">>> $0 >>> Test creating dir $subdir"
"$script" mkdir "$subdir"
test -d "$storage/$subdir"


echo ">>> $0 >>> Test removing empty dir"
! "$script" rm "$subdir"
[ -e "$storage/$subdir" ]


echo ">>> $0 >>> Test command 'edit' with path creating directory"
echo "." | "$script" edit "$subdir/test.md" 1>/dev/null
test -d "$storage/$subdir"


echo ">>> $0 >>> Test removing not empty dir"
"$script" rm "$subdir"
[ ! -e "$storage/$subdir" ]


echo ">>> $0 >>> Test writing blank note with path not creating subdir"
VISUAL=true "$script" edit "$subdir/test.md" 1>/dev/null
[ ! -e "$storage/$subdir" ]


echo ">>> $0 >>> Test writing blank note with path in non empty subdir not deleting subdir"
echo "." | "$script" edit "$subdir/test.md" 1>/dev/null
VISUAL=true "$script" edit "$subdir/test2.md" 1>/dev/null
[ -d "$storage/$subdir" ]