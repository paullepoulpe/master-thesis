#!/usr/bin/env bash
#set -x

SRC=src
TEMPLATES=templates
BUILD=build

if [ ! -d "$BUILD" ]; then 
  mkdir "$BUILD"
fi

# Spell check the files
if [ "$1" = "--spellcheck" ]; then
  # Run interactive mode to fix spelling mistakes
  mdspell --ignore-acronyms --en-us "$SRC/*.md" || exit 1
elif [ "$1" != "--nospellcheck" ]; then
  mdspell --report --ignore-acronyms --en-us "$SRC/*.md"
fi

# Concatenate all files with space in between
rm -f "$BUILD/thesis.md"
for f in "$SRC"/*.md; do 
  cat "${f}"; echo; echo;
done >> "$BUILD/thesis.md";

# Generate both pdf and tex (for inspection)
PDF="$BUILD/thesis.pdf"
TEX="$BUILD/thesis.tex"

for outfile in "$PDF" "$TEX"; do
  echo -n "Compiling thesis to $outfile ..."
  cat "$BUILD/thesis.md" |\
  sed -e "s%/g/png%/g/pdf%" |\
  pandoc -f markdown -t latex \
    --smart \
    --include-in-header=templates/break-sections.tex \
    --include-before-body=templates/titlepage.tex \
    --reference-links \
    --standalone \
    --number-sections \
    --default-image-extension=pdf \
    --toc \
    --highlight-style=tango \
    --filter pandoc-citeproc \
    --bibliography="$SRC/biblio.bib" \
    --csl "$TEMPLATES/computer.csl" \
    -V fontsize=12pt \
    --variable=geometry:a4paper \
    -o $outfile
  echo " Done !"
done

if [ "$1" = "--open" ]; then
  open "$BUILD/thesis.pdf"
fi

