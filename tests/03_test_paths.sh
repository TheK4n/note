#!/bin/sh

. tests/base.sh

echo ">>> $0 >>> Test .. in path cause error"
echo "." | { ! "$script" edit ../some.md 1>/dev/null; }
echo "." | { ! "$script" edit somedir/../../some.md 1>/dev/null; }

echo ">>> $0 >>> Test abs path cause error"
# ! note edit /asdf
echo "." | { ! "$script" edit /somedir/some.md 1>/dev/null; }
echo "." | { ! "$script" edit /usr/some.md 1>/dev/null; }