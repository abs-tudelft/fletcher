#!/bin/bash

# This script builds manylinux{2010, 2014} wheel
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

  for manylinux in 2010 2014; do
    docker build --build-arg MANYLINUX=$manylinux --build-arg PACKAGE=$package -t manylinux-$package:$manylinux  -f "$cwd/Dockerfile.python" "$cwd"
    docker run --rm -v "$project":/io manylinux-$package:$manylinux
  done
done

