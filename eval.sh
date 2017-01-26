#!/bin/bash

GTfolder=$1
PRfolder=$2
Mfolder=$3

evalscript=$4

log=$5

for image in ${GTfolder}/*.png
do 
    $imname=$(basename $image | sed 's/.png//')
    for annot in ${PRfolder}/${imname}*.png
    do
        echo $(python2 evalmasks.py $annot 2048 1024 $Mfolder) > predlist.txt
        echo $image > gtlist.txt

        echo $(python2 $evalscript predlist.txt gtlist.txt) >> $log
    done
done

rm predlist.txt
rm gtlist.txt