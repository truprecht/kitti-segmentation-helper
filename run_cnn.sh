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

if [ -z $1 ]; then
    echo "use $0 <image list> [<output folder>]"
    exit 1
fi
if [ -z $2 ]; then
    OUT="./"
else
    OUT=$(path $2)
    mkdir -p $OUT
fi

IMAGELIST=$1

SCRIPTS="kitti-segmentation-helper/"

PROTOTXT="cnn/test.prototxt"
CAFFEMOD="cnn/cityscapes.caffemodel"

DATA="/tmp/"
CNNOUT="/tmp/fc8_val3769/"
PATCHLIST="test_list.txt"
PATCHLISTID="test_list_id_only.txt"

CRFINPUT="${DATA}input/"
CRFROI="${DATA}roi/"
CRFIMAGE="${DATA}image/"

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
mkdir -p $DATA
touch ${PATCHLIST}_small ${PATCHLIST}_medium ${PATCHLIST}_large

for IMAGE in $(cat $IMAGELIST)
do
    python2 ${SCRIPTS}tools/patchesv2.py $IMAGE $SWIDTH $SHEIGHT $SSTRIDE $LHEIGHT ${DATA}small "_3" >> ${PATCHLIST}_small
    python2 ${SCRIPTS}tools/patchesv2.py $IMAGE $MWIDTH $MHEIGHT $MSTRIDE $LHEIGHT ${DATA}medium "_2" >> ${PATCHLIST}_medium
    python2 ${SCRIPTS}tools/patchesv2.py $IMAGE $LWIDTH $LHEIGHT $LSTRIDE $LHEIGHT ${DATA}large "_1" >> ${PATCHLIST}_large
done

mkdir -p $CRFINPUT

# run cnn test on different patch sizes seperately, move 'em to data folder
for size in small medium large
do
    rm -r $CNNOUT &> /dev/null
    mkdir -p $CNNOUT

    cp ${PATCHLIST}_${size} $PATCHLIST
    cat $PATCHLIST | sed 's:\.png::g' | sed 's:[^ ]*/::g' > $PATCHLISTID
    # count files listed in test_list_id_only.txt
    iterations=$(wc -w $PATCHLISTID  | grep -o "^[0-9]\+")
    srun caffe test -model=$PROTOTXT -weights=$CAFFEMOD -iterations $iterations -gpu 0

    mv $CNNOUT ${CRFINPUT}$size
done
rm ${PATCHLIST}_small ${PATCHLIST}_medium ${PATCHLIST}_large &> /dev/null


# move roi files to densecrf
mkdir -p $CRFROI
mv ${DATA}small/*.txt $CRFROI
mv ${DATA}medium/*.txt $CRFROI
mv ${DATA}large/*.txt $CRFROI
rm -r ${DATA}small ${DATA}medium ${DATA}large

# move image to densecrf
mkdir -p $CRFIMAGE
for IMAGE in $(cat $IMAGELIST)
do
    cp $IMAGE $CRFIMAGE
done

tar -czf "${OUT}input.tar.gz" "$CRFINPUT"
rm -r $CRFINPUT
tar -czf "${OUT}image.tar.gz" "$CRFIMAGE"
rm -r $CRFIMAGE
tar -czf "${OUT}roi.tar.gz" "$CRFROI"
rm -r $CRFROI