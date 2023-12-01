#!/usr/bin/env bash

source tests/base.sh

echo ">>> $0 >>> Test .. in path cause error"
if echo "." | "$script" edit ../some.md 1>/dev/null; then false; else true; fi
if echo "." | "$script" edit somedir/../../some.md 1>/dev/null; then false; else true; fi

echo ">>> $0 >>> Test abs path cause error"
# ! note edit /asdf
if echo "." | "$script" edit /somedir/some.md 1>/dev/null; then false; else true; fi
if echo "." | "$script" edit /usr/some.md 1>/dev/null; then false; else true; fi
