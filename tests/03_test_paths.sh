#!/usr/bin/env bash

set -e

export EDITOR=tee
export CAT=cat

script="./note.sh"

echo ">>> $0 >>> Test .. in path cause error"
if echo "." | "$script" edit ../some.md; then false; else true; fi
if echo "." | "$script" edit somedir/../../some.md; then false; else true; fi

echo ">>> $0 >>> Test abs path cause error"
# ! note edit /asdf
if echo "." | "$script" edit /somedir/some.md; then false; else true; fi
if echo "." | "$script" edit /usr/some.md; then false; else true; fi
