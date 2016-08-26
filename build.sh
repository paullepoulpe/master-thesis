#!/usr/bin/env bash

open=false
interactive_spellcheck=false
batch_spellcheck=true

while test $# -gt 0
do
    case "$1" in
        --spellcheck) interactive_spellcheck=true
            ;;
        --nospellcheck) batch_spellcheck=false
            ;;
        --open) open=true
            ;;
        *) echo "unrecognized option $1"
            ;;
    esac
    shift
done

if [ ! -d build ]; then 
  mkdir build
fi

# Spell check the files
if [ $interactive_spellcheck = true ]; then
  # Run interactive mode to fix spelling mistakes
  mdspell --ignore-acronyms --en-us src/*.md || exit 1
elif [ $batch_spellcheck = true ]; then
  mdspell --report --ignore-acronyms --en-us src/*.md
fi

# Concatenate all files with space in between
rm -f build/thesis.md
for f in src/*.md; do 
  cat "${f}"; echo; echo;
done >> build/thesis.md;

# Generate both pdf and tex (for inspection)
outputs=(pdf    tex     docx)
formats=(latex  latex   '')

for idx in "${!outputs[@]}"; do
  outfile="build/thesis.${outputs[$idx]}"
  format="${formats[$idx]}"
  if [ ! -z $format ]; then
    format="-t $format"
  fi
  echo -n "Compiling thesis to $outfile with ($format) ..."
  cat build/thesis.md |\
  sed -e "s%/g/png%/g/pdf%" |\
  pandoc -f markdown $format \
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
    --bibliography=src/biblio.bib \
    --csl templates/computer.csl \
    -V fontsize=12pt \
    --variable=geometry:a4paper \
    -o $outfile
  echo " Done !"
done

if [ $open = true ]; then
  open build/thesis.pdf
fi

