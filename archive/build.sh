#!/bin/sh

mkdir bin || exit 1
javac \
    src/jstoch/*/*.java \
    src/landusemodel/*.java \
    -d bin \
    -cp colt/colt.jar:gson/gson-2.8.6.jar:junit/junit-4.13.jar
