#!/bin/bash

CSROOT=$1
PRfolder=$2
Mfolder=$3

evalscript=$4

mkdir -p ${Mfolder}

for prediction in ${PRfolder}*.png
do
    pname=$(basename $prediction | sed 's/.png//')
    python2 evalmasks.py $prediction 2048 1024 $Mfolder > ${Mfolder}${pname}.txt
done

export CITYSCAPES_DATASET=$CSROOT
export CITYSCAPES_RESULTS=$Mfolder

python $evalscript