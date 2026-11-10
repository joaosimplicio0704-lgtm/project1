#!/usr/bin/env sh
# Testes offline (nao precisam de Windows nem do cliente).
#   ./tests/run.sh
set -eu

CXX="${CXX:-g++}"
cd "$(dirname "$0")/.."

mkdir -p build
$CXX -std=c++20 -O1 -g -Wall -Wextra \
    tests/math_test.cpp src/config.cpp \
    -o build/math_test

exec ./build/math_test
