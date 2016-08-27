#!/usr/bin/env bash
# For now this is how we build plots, but in the future it would be nice to be
# able to build them on a server, so the markdown can show pretty graphs too

mkdir -p out

for app in tpchq1 tpchq6; do
  for format in png pdf; do
    tempFile=$app.$format.temp.gp
    echo -n "Generating out/$app.$format"
    (
      cat formats/$format | sed -e 's|%filename%|out/'$app'|g'
      cat src/$app.gp
    ) > $tempFile
    gnuplot $tempFile
    res=$?
    if [ $res -eq 0 ]; then
      echo " => Success"
    else
      echo " => Failed"
    fi
    rm -f $tempFile
  done
done
