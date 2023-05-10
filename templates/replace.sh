#!/bin/bash

# check if both arguments are supplied
if [ $# -ne 2 ]; then
    echo "Usage: $0 <filename> <newstring>"
    exit 1
fi

# check if file exists
if [ ! -f "$1" ]; then
    echo "File $1 not found"
    exit 1
fi

# replace all instances of XXX with second argument
sed "s/\<T\>/$2/g" "$1"
