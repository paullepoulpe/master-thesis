#!/usr/bin/env bash
#set -x

SRC_FOLDER=src

fswatch -o "$SRC_FOLDER" | xargs -n1 ./build.sh --nospellcheck

