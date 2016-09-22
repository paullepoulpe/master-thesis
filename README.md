# Master Thesis
by [Damien Engels](https://github.com/paullepoulpe)

This is the source for the final report of my master's thesis at [EPFL](http://epfl.ch). In the report, I present the work I have done over 6 months at the Pervasive Parallelism Lab ([PPL](https://ppl.stanford.edu/)) in Stanford in conjunction with the Programming Methods Laboratory ([LAMP](http://lamp.epfl.ch)) at EPFL.

## Usage
**Warning:** Only runs on MacOS. There is no reason why you could not use it on another platform, but I did not bother adding support. If you want to use it, you'll have to figure it out yourself.

### Install dependencies

The tools needed to compile the report are:

- pandoc
- latex
- markdown-spellchecker (non-essential)
- fswatch (non-essential)

You can install all those tools by running the following script that will check which dependencies are missing and install them for you:

```bash
bash> ./install.sh
```

### Build the report

To generate a pdf from the sources, run the following script:

```bash
bash> ./build.sh
```

The resulting file can be found in `build/thesis.pdf`. By default the script creates a resulting document in pdf format without failing on spellcheck errors, but the scripts also supports the following options:

- `--spellcheck`: run the spellchecker in interactive mode to fix spelling mistakes
- `--no-spellcheck`: don't warn about spelling mistakes
- `--open`: open the resulting document
- `--pdf`: output pdf document (default)
- `--tex`: output latex document
- `--docx`: output word document (does not include title page)


If you want the report to be generated each time the source changes, you can run:

```bash
bash> ./auto.sh
```

### Writing
The report is written using pandoc's version of Markdown ([http://pandoc.org/MANUAL.html#pandocs-markdown](http://pandoc.org/MANUAL.html#pandocs-markdown)).

The sources can be found in the `src` folder.

Al the dynamic figures (graphs, plots) are generated using [markdown-tech](https://markdown.tech).

## Design

The project is structured as follows:

- `src`
    - `*.md`
    - `biblio.bib`
- `images`
- `templates`
    - `break-sections.tex`
    - `computer.csl`
    - `titlepage.tex`

All of the files are located in the `src` folder. They have to be ordered by name, so they are all prefixed with their respective section number. The bibliography can be found in `src/biblio.bib` and is in standard bibtex format. All of the images or contained in the `images` subfolder. 

The `templates` folder contains the latex templates that are included before generating the pdf. Theses include a template that makes sure a new page is allocated every time a section starts as well as the template that creates the title page. `templates/computer.csl` defines the citation style in the resulting document.

