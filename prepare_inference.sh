#!/bin/bash

#SBATCH --time=4:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=10583M
#SBATCH --mail-user=thomas.ruprecht@tu-dresden.de
#SBATCH --mail-type=END,FAIL

if [ -z $1 ]
then
    echo "use $0 <input folder> <scripts>"
    exit 1
fi

function path() {
    if [ "${1: -1}" != "/" ]
    then
        echo $1/
    else
        echo $1
    fi
}

DATA=$(path $1)
RSMPL=$(path $2)tools/resample.py
SCLIMG=$(path $2)tools/scale-image.py
SCLROI=$(path $2)tools/scale-roi.py

IMAGES=${DATA}image.tar.gz
PATCHES=${DATA}input.tar.gz
ROIS=${DATA}roi.tar.gz

tar -xzf $IMAGES
tar -xzf $PATCHES
tar -xzf $ROIS

PATCHES=${DATA}input
IMAGES=${DATA}image
ROIS=${DATA}roi
LIST=${PATCHES}/filelist.txt


SWIDTH=275
SHEIGHT=330

MWIDTH=400
MHEIGHT=500

LWIDTH=600
LHEIGHT=750

touch $LIST

python2 $RSMPL $PATCHES/small $(($SWIDTH/4)) $(($SHEIGHT/4)) $PATCHES
python2 $RSMPL $PATCHES/medium $(($MWIDTH/4)) $(($MHEIGHT/4)) $PATCHES
python2 $RSMPL $PATCHES/large $(($LWIDTH/4)) $(($LHEIGHT/4)) $PATCHES


for im in $IMAGES/*
do
    python2 $SCLIMG $im 512 256 $im
    echo "resized image $im"
done
for roi in $ROIS/*
do
    if [[ $roi == *_1_*.txt ]]
    then
        python2 $SCLROI $roi $(($LWIDTH/4)) $(($LHEIGHT/4))
    elif [[ $roi == *_2_*.txt ]]
    then
        python2 $SCLROI $roi $(($MWIDTH/4)) $(($MHEIGHT/4))
    elif [[ $roi == *_3_*.txt ]]
    then
        python2 $SCLROI $roi $(($SWIDTH/4)) $(($SHEIGHT/4))
    fi
    echo "rescaled roi $roi"
done