#!/bin/bash

CSROOT=$1
PRfolder=$2
Mfolder=$3

evalscript=$4

mkdir -p ${Mfolder}

echo "cutting binary masks for images"
predictions=$(ls $PRfolder | wc | grep -o "^[^0-9]*[0-9]\+" | grep -o "[0-9]\+")
i=1

for prediction in ${PRfolder}*.png
do
    pname=$(basename $prediction | sed 's/.png//')
    python2 evalmasks.py $prediction 2048 1024 $Mfolder > ${Mfolder}${pname}.txt
    echo "done $i / $predictions"
    i=$(($i+1))
done

export CITYSCAPES_DATASET=$CSROOT
export CITYSCAPES_RESULTS=$Mfolder

python $evalscript