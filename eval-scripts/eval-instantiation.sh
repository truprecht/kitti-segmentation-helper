#!/bin/bash

#SBATCH --time=3:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24
#SBATCH --mem-per-cpu=2583M
#SBATCH --mail-user=thomas.ruprecht@tu-dresden.de
#SBATCH --mail-type=END,FAIL

export OMP_NUM_THREADS=24

function path() {
    if [ "${1: -1}" != "/" ]
    then
        echo $1/
    else
        echo $1
    fi
}

if [ -z $1 ]; then
    echo "use $0 <prediction folder> <annotated image list>"
fi

SCRIPTS="kitti-segmentation-helper/tools/"
TMP="/tmp/patches/"

SWIDTH=275
SHEIGHT=330
SSTRIDE=50

MWIDTH=400
MHEIGHT=500
MSTRIDE=80

LWIDTH=600
LHEIGHT=750
LSTRIDE=120

pred=$(path $1)
cat $2 | awk '{ print $2 }' > "/tmp/annots"
cat $2 | awk '{ print $1 }' | sed "s:^.*/:$pred:" | paste - "/tmp/annots" > "/tmp/annots.1"

threads=0
while read pair; do
    lp=( $pair)
    if [ $threads -ge $(($OMP_NUM_THREADS - 2)) ]; then
        wait
        threads=0
    fi
    threads=$(($threads + 3))
    python2 ${SCRIPTS}patchesv2.py ${lp[0]} $SWIDTH $SHEIGHT $SSTRIDE $LHEIGHT ${TMP} _3 ${lp[1]} &
    python2 ${SCRIPTS}patchesv2.py ${lp[0]} $MWIDTH $MHEIGHT $MSTRIDE $LHEIGHT ${TMP} _2 ${lp[1]} &
    python2 ${SCRIPTS}patchesv2.py ${lp[0]} $LWIDTH $LHEIGHT $LSTRIDE $LHEIGHT ${TMP} _1 ${lp[1]} &
done < "/tmp/annots.1"


for annot in ${TMP}*_annot.png; do
    echo "$(echo $annot | sed 's/_annot//') $annot" >> "/tmp/annots.patches"
done

python "kitti-segmentation-helper/eval-scripts/eval-instantiation.py" summary "/tmp/annots.patches" 24

rm "/tmp/annots*"
rm -r "/tmp/patches/"
