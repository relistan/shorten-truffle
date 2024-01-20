#!/bin/bash

SCRIPT=$1
CLASSPATH=`cat cp.txt`
ruby --vm.classpath=$CLASSPATH $SCRIPT
