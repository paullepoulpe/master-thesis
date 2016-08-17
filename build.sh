#!/usr/bin/env bash
set -x

SRC_FOLDER=src
BUILD_FOLDER=build

if [ ! -d "$BUILD_FOLDER" ]; then 
  mkdir "$BUILD_FOLDER"
fi

pandoc -f markdown -t latex "$SRC_FOLDER"/*.md -o "$BUILD_FOLDER/thesis.pdf" 

if [ "$1" = "--open" ]; then
  open "$BUILD_FOLDER/thesis.pdf"
fi
#
#  --metadata link-citations \
#  --no-wrap \
#  --toc \
#  --number-sections \
#  --default-image-extension=extension \
#  --bibliography=FILE \
#  --biblatex \
#  --reference-links \
#  --variable=geometry:a4paper \
#  "$BUILD_FOLDER/thesis.tex"
