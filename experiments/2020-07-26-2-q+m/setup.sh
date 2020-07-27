#!/bin/sh

which parallel || exit 1
which R || exit 1
which java || exit 1
which python3 || exit 1
cd `dirname $0`
./setup.R
