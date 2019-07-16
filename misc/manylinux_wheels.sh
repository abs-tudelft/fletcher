#!/bin/bash

# This script builds manylinux{1, 2010} wheels in runtime/python/build/dist
# Usage: ./manylinux_wheels.sh

set -e -x

dir="$(dirname "${BASH_SOURCE[0]}")"
cwd=`eval "cd $dir;pwd;cd - > /dev/null"`
dir="$cwd/.."
project=`eval "cd $dir;pwd;cd - > /dev/null"`

# Remove old build files
cd $project/runtime/python
python3 setup.py clean

# Remove eggs
eggs="$project/runtime/python/.eggs"
rm -rf $eggs

# Make sure target dir is empty
target="$project/runtime/python/build"
rm -rf $target

# docker build -t pyfletcher-manylinux:1 -f "$cwd/Dockerfile.python" "$cwd"
# docker run --rm -v "$project":/io pyfletcher-manylinux:1

docker build --build-arg MANYLINUX=2010 -t pyfletcher-manylinux:2010 -f "$cwd/Dockerfile.python" "$cwd"
docker run --rm -v "$project":/io pyfletcher-manylinux:2010
