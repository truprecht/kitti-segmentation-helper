#!/bin/bash

#SBATCH --time=24:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24
#SBATCH --mem-per-cpu=2583M
#SBATCH --mail-user=thomas.ruprecht@tu-dresden.de
#SBATCH --mail-type=END,FAIL

export OMP_NUM_THREADS=24


if [ -z $1 ] || [ -z $2 ] || [ -z $3 ] || [ -z $4 ]
then
    echo "use $0 <image folder> <annotation folder> <output folder> <output list> [<working dir>] [<statistics file>]"
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

if [ -z $5 ]
then
    SCRIPTS=$(pwd)
else
    SCRIPTS=$5
fi

IMAGES=$(path $1)
LABELS=$(path $2)
OUT=$(path $3)
SCRIPTS=$(path $5)

SWIDTH=275
SHEIGHT=330
SSTRIDE=50

MWIDTH=400
MHEIGHT=500
MSTRIDE=80

LWIDTH=600
LHEIGHT=750
LSTRIDE=120

mkdir -p $3

rm $4
touch $4

for folder in ${IMAGES}*
do
    cf="$(basename $folder)/"
    for image in ${folder}/*
    do
        annot=${LABELS}${cf}$(basename $image | sed 's/_leftImg8bit/_gtFine_instanceTrainIds/')

        echo "cutting $image / $annot"
        
        python2 ${SCRIPTS}patchesv2.py $image $SWIDTH $SHEIGHT $SSTRIDE $LHEIGHT ${OUT} _3 $annot >> $4
        python2 ${SCRIPTS}patchesv2.py $image $MWIDTH $MHEIGHT $MSTRIDE $LHEIGHT ${OUT} _2 $annot >> $4
        python2 ${SCRIPTS}patchesv2.py $image $LWIDTH $LHEIGHT $LSTRIDE $LHEIGHT ${OUT} _1 $annot >> $4
    done
done

if ! [[ -z $6 ]]; then
    for annotfile in ${OUT}/*annot.png; do
        echo "$annotfile $(python2 ${SCRIPTS}uniques.py $annotfile)" >> $6
    done
fi