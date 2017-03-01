#!/bin/bash

#SBATCH --time=2:00:00
#SBATCH --nodes=1
#SBATCH --gres=gpu:1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=3
#SBATCH --mem-per-cpu=3000M
#SBATCH --mail-user=thomas.ruprecht@tu-dresden.de
#SBATCH --mail-type=END,FAIL


function path() {
    if [ "${1: -1}" != "/" ]
    then
        echo $1/
    else
        echo $1
    fi
}

if [ -z $1 ] || [ -z $2 ] || [ -z $3 ] || [ -z $4 ]
then
    echo "use $0 <project root> <image list> <scripts> <output folder>"
    exit 1
fi

ROOT=$(path $1)
IMAGELIST=$2
SCRIPTS=$(path $3)
OUT=$(path $4)

PROTOTXT="${ROOT}cnn/test.prototxt"
CAFFEMOD="${ROOT}cnn/cityscapes.caffemodel"

DATA="temp/"
CNNOUT="fc8_val3769/"
PATCHLIST="test_list.txt"
PATCHLISTID="test_list_id_only.txt"

CRFINPUT="${OUT}input/"
CRFROI="${OUT}roi/"
CRFIMAGE="${OUT}image/"

SWIDTH=275
SHEIGHT=330
SSTRIDE=50

MWIDTH=400
MHEIGHT=500
MSTRIDE=80

LWIDTH=600
LHEIGHT=750
LSTRIDE=120

#
# cut image patches
# call patches.py <image> <patchwidth> <patchheight> <stride in x direction> <offset in y direction> <output folder> <output name postfix>
# st. output name := basename + postfix + autoincrement + file postfix, 
# if input name = basename + file postfix
#
rm -r $DATA &> /dev/null
mkdir -p $DATA

mkdir -p $CRFINPUT
mkdir -p $CNNOUT

for IMAGE in $(cat $IMAGELIST)
do
    rm ${PATCHLIST}
    touch ${PATCHLIST}
    if [[ $IMAGE == *_small.png ]]
    then
        python2 ${SCRIPTS}patchesv2.py $IMAGE $(($SWIDTH/4)) $(($SHEIGHT/4)) $(($SSTRIDE/4)) $(($LHEIGHT/4)) ${DATA} "_3" >> ${PATCHLIST}
        python2 ${SCRIPTS}patchesv2.py $IMAGE $(($MWIDTH/4)) $(($MHEIGHT/4)) $(($MSTRIDE/4)) $(($LHEIGHT/4)) ${DATA} "_2" >> ${PATCHLIST}
        python2 ${SCRIPTS}patchesv2.py $IMAGE $(($LWIDTH/4)) $(($LHEIGHT/4)) $(($LSTRIDE/4)) $(($LHEIGHT/4)) ${DATA} "_1" >> ${PATCHLIST}
    elif [[ $IMAGE == *_sparse.png ]]
    then
        python2 ${SCRIPTS}patchesv2.py $IMAGE $SWIDTH $SHEIGHT $(($SSTRIDE*2)) $LHEIGHT ${DATA} "_3" >> ${PATCHLIST}
        python2 ${SCRIPTS}patchesv2.py $IMAGE $MWIDTH $MHEIGHT $(($MSTRIDE*2)) $LHEIGHT ${DATA} "_2" >> ${PATCHLIST}
        python2 ${SCRIPTS}patchesv2.py $IMAGE $LWIDTH $LHEIGHT $(($LSTRIDE*2)) $LHEIGHT ${DATA} "_1" >> ${PATCHLIST}
    else
        python2 ${SCRIPTS}patchesv2.py $IMAGE $SWIDTH $SHEIGHT $SSTRIDE $LHEIGHT ${DATA} "_3" >> ${PATCHLIST}
        python2 ${SCRIPTS}patchesv2.py $IMAGE $MWIDTH $MHEIGHT $MSTRIDE $LHEIGHT ${DATA} "_2" >> ${PATCHLIST}
        python2 ${SCRIPTS}patchesv2.py $IMAGE $LWIDTH $LHEIGHT $LSTRIDE $LHEIGHT ${DATA} "_1" >> ${PATCHLIST}
    fi
    
    python2 ${SCRIPTS}idonly.py $PATCHLIST > $PATCHLISTID
    iterations=$(wc -w $PATCHLISTID  | grep -o "^[0-9]\+")
    srun caffe test -model=$PROTOTXT -weights=$CAFFEMOD -iterations $iterations -gpu 0
    locout=${CRFINPUT}$(basename $IMAGE)
    mkdir -p $locout/small
    mkdir -p $locout/medium
    mkdir -p $locout/large
    mv ${CNNOUT}*_3_* $locout/small/
    mv ${CNNOUT}*_2_* $locout/medium/
    mv ${CNNOUT}*_1_* $locout/large/
done


# move roi files to densecrf
mkdir -p $CRFROI
mv ${DATA}*.txt $CRFROI
#rm -r ${DATA}

# move image to densecrf
mkdir -p $CRFIMAGE
for IMAGE in $(cat $IMAGELIST)
do
    cp $IMAGE $CRFIMAGE
done

tar -czf ${OUT}input.tar.gz $CRFINPUT
rm -r $CRFINPUT
tar -czf ${OUT}image.tar.gz $CRFIMAGE
rm -r $CRFIMAGE
tar -czf ${OUT}roi.tar.gz $CRFROI
rm -r $CRFROI