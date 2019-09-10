#!/bin/bash

# This script builds manylinux{1, 2010} wheels in runtime/python/build/dist
# Usage: ./manylinux_wheels.sh

set -e -x

dir="$(dirname "${BASH_SOURCE[0]}")"
cwd=`eval "cd $dir;pwd;cd - > /dev/null"`
dir="$cwd/.."
project=`eval "cd $dir;pwd;cd - > /dev/null"`

for package in runtime/python codegen/python; do
  # Remove old build files
  cd $project/$package
  python3 setup.py clean

  # Remove eggs
  eggs="$project/$package/.eggs"
  rm -rf $eggs

  docker build --build-arg MANYLINUX=2010 --build-arg PACKAGE=$package -t manylinux-$package:2010 -f "$cwd/Dockerfile.python" "$cwd"
  docker run --rm -v "$project":/io manylinux-$package:2010
done

