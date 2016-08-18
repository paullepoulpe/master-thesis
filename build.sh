#!/usr/bin/env bash
#set -x

SRC=src
TEMPLATES=templates
BUILD=build

if [ ! -d "$BUILD" ]; then 
  mkdir "$BUILD"
fi

# Concatenate all files with space in between
rm -f "$BUILD/thesis.md"
for f in "$SRC"/*.md; do 
  cat "${f}"; echo
done >> "$BUILD/thesis.md";

# Generate both pdf and tex (for inspection)
PDF="$BUILD/thesis.pdf"
TEX="$BUILD/thesis.tex"

for outfile in "$PDF" "$TEX"; do
  echo "Compiling thesis to $outfile ..."
  cat "$BUILD/thesis.md" |\
  sed -e "s%/g/png%/g/pdf%" |\
  pandoc -f markdown -t latex \
    --smart \
    --template="$TEMPLATES/default.latex" \
    --standalone \
    --number-sections \
    --default-image-extension=pdf \
    --toc \
    --filter pandoc-citeproc \
    --bibliography="$SRC/biblio.bib" \
    --csl "$TEMPLATES/computer.csl" \
    -V fontsize=12pt \
    --variable=geometry:a4paper \
    -o $outfile
done

if [ "$1" = "--open" ]; then
  open "$BUILD/thesis.pdf"
fi

