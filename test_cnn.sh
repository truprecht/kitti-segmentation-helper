#!/bin/bash

#SBATCH --time=4:00:00
#SBATCH --nodes=1
#SBATCH --gres=gpu:1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=3
#SBATCH --mem-per-cpu=3000M
#SBATCH --mail-user=thomas.ruprecht@tu-dresden.de
#SBATCH --mail-type=END,FAIL



# bash kitti-segmentation-helper/test_cnn.sh valfiles100.txt cityscapes/gtFine_trainvaltest/gtFine/val/frankfurt/ kitti-segmentation-helper/ snapshots.txt

FILES=$1
GT=$2
SCRIPTS=$3
CAFFEMODELS=$4

CNNOUT="fc8_val3769/"
PROTOTXT="cnn-densecrf-kitti-public/cnn/test.prototxt"
mkdir -p $CNNOUT

DATA="temp/"
PATCHES="${DATA}patches/"
PATCHLIST="${PATCHES}list.txt"
PREDICTIONS="${DATA}pred/"
TESTLIST="test_list.txt"
TESTLISTID="test_list_id_only.txt"
mkdir -p $PATCHES
mkdir -p $PREDICTIONS

SWIDTH=275
SHEIGHT=330
SSTRIDE=50

MWIDTH=400
MHEIGHT=500
MSTRIDE=80

LWIDTH=600
LHEIGHT=750
LSTRIDE=120

# for model in $(cat $CAFFEMODELS)
# do 
#     modelname=$(basename $model)
#     mkdir ${PREDICTIONS}${modelname}.d
# done

# for file in $(cat $FILES)
# do
#     annot=$(basename $file | sed 's/leftImg8bit/gtFine_labelIds/')
#     class=${DATA}${annot}
    
#     python2 ${SCRIPTS}binary.py ${GT}${annot} 26 $class
    
#     touch $PATCHLIST
#     python2 ${SCRIPTS}patchesv2.py $file $SWIDTH $SHEIGHT $SSTRIDE $LHEIGHT ${PATCHES} "_3" $class >> ${PATCHLIST}
#     python2 ${SCRIPTS}patchesv2.py $file $MWIDTH $MHEIGHT $MSTRIDE $LHEIGHT ${PATCHES} "_2" $class >> ${PATCHLIST}
#     python2 ${SCRIPTS}patchesv2.py $file $LWIDTH $LHEIGHT $LSTRIDE $LHEIGHT ${PATCHES} "_1" $class >> ${PATCHLIST}
    
#     cat $PATCHLIST | grep -o "^[^[:space:]]\+" > $TESTLIST
#     python2 ${SCRIPTS}idonly.py $TESTLIST > $TESTLISTID
#     rm $PATCHLIST
#     rm $class
    
#     iterations=$(wc -w $TESTLISTID  | grep -o "^[0-9]\+")
    
#     for model in $(cat $CAFFEMODELS)
#     do
#         caffe test -model=$PROTOTXT -weights=$model -iterations $iterations -gpu 0
#         modelname=$(basename $model)
#         mv $CNNOUT/* ${PREDICTIONS}${modelname}.d/
#     done
# done

for model in ${PREDICTIONS}*
do
    for prediction in $model/*
    do
        gt=$(basename $prediction | sed 's/_blob_0.mat/_annot.png/')
        python2 ${SCRIPTS}evalclass.py ${PATCHES}${gt} $prediction >> ${model}/performance.txt
    done
done