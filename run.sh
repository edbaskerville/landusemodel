#!/bin/sh

ROOT_DIR=`dirname $0`
java -cp "$ROOT_DIR/bin:$ROOT_DIR/colt/colt.jar:$ROOT_DIR/gson/gson-2.8.6.jar:$ROOT_DIR/junit/junit-4.13.jar" \
    landusemodel.Main $@
