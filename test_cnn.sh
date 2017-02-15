# bash kitti-segmentation-helper/test_cnn.sh valfiles100.txt cityscapes/gtFine_trainvaltest/gtFine/val/frankfurt/ kitti-segmentation-helper/ snapshots.txt

FILES=$1
GT=$2
SCRIPTS=$3
CAFFEMODELS=$4

CNNOUT="fc8_val3769/"
PROTOTXT="cnn-densecrf-kitti-public/cnn/test.prototxt"

DATA="temp/"
PATCHES="${DATA}patches/"
PATCHLIST="${PATCHES}list.txt"
PREDICTIONS="${DATA}pred/"
TESTLIST="test_list.txt"
TESTLISTID="testlist_id_only.txt"
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

for file in $(cat $FILES)
do
    annot=$(basename $file | sed 's/leftImg8bit/gtFine_labelIds/')
    class=${DATA}${annot}
    
    python2 ${SCRIPTS}binary.py ${GT}${annot} 26 $class
    
    touch $PATCHLIST
    python2 ${SCRIPTS}patchesv2.py $file $SWIDTH $SHEIGHT $SSTRIDE $LHEIGHT ${PATCHES} "_3" $class >> ${PATCHLIST}
    python2 ${SCRIPTS}patchesv2.py $file $MWIDTH $MHEIGHT $MSTRIDE $LHEIGHT ${PATCHES} "_2" $class >> ${PATCHLIST}
    python2 ${SCRIPTS}patchesv2.py $file $LWIDTH $LHEIGHT $LSTRIDE $LHEIGHT ${PATCHES} "_1" $class >> ${PATCHLIST}
    
    cat $PATCHLIST | grep -o "^[^[:space:]]\+" > $TESTLIST
    python2 ${SCRIPTS}idonly.py $TESTLIST > $TESTLISTID
    rm $PATCHLIST
    rm $class
    
    iterations=$(wc -w $TESTLISTID  | grep -o "^[0-9]\+")
    
    for model in $(cat $CAFFEMODELS)
    do
        mkdir -p $CNNOUT
        caffe test -model=$PROTOTXT -weights=$model -iterations $iterations -gpu 0
        modelname=$(basename $model)
        mv $CNNOUT ${PREDICTIONS}${modelname}.d
    done
done