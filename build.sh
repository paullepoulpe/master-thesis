#!/usr/bin/env bash
#set -x

SRC_FOLDER=src
BUILD_FOLDER=build

if [ ! -d "$BUILD_FOLDER" ]; then 
  mkdir "$BUILD_FOLDER"
fi


#  --metadata link-citations -> ???

#  --number-sections 
#       Number section headings in LaTeX, ConTeXt, HTML, or EPUB output. By
#       default, sections are not numbered. Sections with class unnumbered will
#       never be numbered, even if --number-sections is specified.

#  --wrap=[auto|none|preserve]
#       Determine how text is wrapped in the output (the source code, not the
#       rendered version). With auto (the default), pandoc will attempt to wrap
#       lines to the column width specified by --columns (default 80). With
#       none, pandoc will not wrap lines at all. With preserve, pandoc will
#       attempt to preserve the wrapping from the source document (that is,
#       where there are non-semantic newlines in the source, there will be
#       nonsemantic newlines in the output as well).

#  --toc
#       Include an automatically generated table of contents (or, in the case of
#       latex, context, docx, and rst, an instruction to create one) in the
#       output document. This option has no effect on man, docbook, docbook5,
#       slidy, slideous, s5, or odt output.

#  --default-image-extension=EXTENSION
#       Specify a default extension to use when image paths/URLs have no
#       extension. This allows you to use the same source for formats that
#       require different kinds of images. Currently this option only affects
#       the Markdown and LaTeX readers.

#  --bibliography=FILE -> Set bibliography file
#       Set the bibliography field in the document's metadata to FILE,
#       overriding any value set in the metadata, and process citations using
#       pandoc-citeproc. (This is equivalent to --meta- data bibliography=FILE
#       --filter pandoc-citeproc.) If --natbib or --biblatex is also supplied,
#       pandoc-citeproc is not used, making this equivalent to --metadata
#       bibliography=FILE. If you supply this argument multiple times, each FILE
#       will be added to bibliography.

#  --biblatex
#       Use biblatex for citations in LaTeX output. This option is not for use
#       with the pandoc-citeproc filter or with PDF output. It is intended for
#       use in producing a LaTeX file that can be processed with bibtex or
#       biber.

#  --reference-links
#       Use reference-style links, rather than inline links, in writing Markdown
#       or reStructuredText. By default inline links are used.

#  --variable=geometry:a4paper
#       option for geometry package, e.g. margin=1in; may be repeated for
#       multiple options


# Concatenate all files with space in between
rm "$BUILD_FOLDER/thesis.md"
for f in "$SRC_FOLDER"/*.md; do 
  cat "${f}"; echo
done >> "$BUILD_FOLDER/thesis.md";

# Generate both pdf and tex (for inspection)
PDF="$BUILD_FOLDER/thesis.pdf"
TEX="$BUILD_FOLDER/thesis.tex"

for outfile in "$PDF" "$TEX"; do
  echo "Compiling thesis to $outfile ..."
  cat "$BUILD_FOLDER/thesis.md" |\
  sed -e "s%/g/png%/g/pdf%" |\
  pandoc -f markdown -t latex \
    --number-sections \
    --default-image-extension=pdf \
    --toc \
    --variable=geometry:a4paper \
    -o $outfile
done

if [ "$1" = "--open" ]; then
  open "$BUILD_FOLDER/thesis.pdf"
fi

