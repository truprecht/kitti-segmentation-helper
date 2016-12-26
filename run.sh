#!/bin/bash

if [ -z $1 ] || [ -z $2 ]
then
    echo "use $0 <project root> <image file> [<scripts folder>]"
    exit 1
fi

if [ -z $3 ]
then
    SCRIPTS=$(pwd)
else
    SCRIPTS=$3
fi

# SETUP
ROOT=$1
if [ "${ROOT: -1}" != "/" ]
then
    ROOT="${ROOT}/"
fi
if [ "${SCRIPTS: -1}" != "/" ]
then
    SCRIPTS="${SCRIPTS}/"
fi
IMAGE=$2
DATA="${ROOT}data/"

CNNOUT="${ROOT}cnn/fc8_val3769/"
PROTOTXT="${ROOT}cnn/test.prototxt"
CAFFEMOD="${ROOT}cnn/deeplab-kitti-60k.caffemodel"
PATCHLIST="test_list.txt"
PATCHLISTID="test_list_id_only.txt"

CRFINPUT="${ROOT}densecrf/data/input/"
CRFROI="${ROOT}densecrf/data/roi/"
CRFIMAGE="${ROOT}densecrf/data/image/"
CRFRESULTS="${ROOT}densecrf/data/results/"

SWIDTH=192
SHEIGHT=120
SSTRIDE=32

MWIDTH=288
MHEIGHT=180
MSTRIDE=48

LWIDTH=432
LHEIGHT=270
LSTRIDE=72

#
# cut image patches
# call patches.py <image> <patchwidth> <patchheight> <stride in x direction> <offset in y direction> <output folder> <output name postfix>
# st. output name := basename + postfix + autoincrement + file postfix, 
# if input name = basename + file postfix
#
rm -r $DATA &> /dev/null || echo "data folder does not exist"
mkdir -p $DATA
(rm $PATCHLIST &> /dev/null; rm $PATCHLISTID &> /dev/null)  || echo "id lists do not exist"
touch $PATCHLIST
#cd cnn
python2 ${SCRIPTS}patchesv2.py $IMAGE $SWIDTH $SHEIGHT $SSTRIDE $LHEIGHT ${DATA}small "_3" > ${PATCHLIST}_small
python2 ${SCRIPTS}patchesv2.py $IMAGE $MWIDTH $MHEIGHT $MSTRIDE $LHEIGHT ${DATA}medium "_2" > ${PATCHLIST}_medium
python2 ${SCRIPTS}patchesv2.py $IMAGE $LWIDTH $LHEIGHT $LSTRIDE $LHEIGHT ${DATA}large "_1" > ${PATCHLIST}_large

# run cnn test on different patch sizes seperately, move 'em to data folder
for size in small medium large
do
    rm -r $CNNOUT &> /dev/null || echo "output folder does not exist"
    mkdir -p $CNNOUT

    cp ${PATCHLIST}_${size} $PATCHLIST
    python2 ${SCRIPTS}idonly.py $PATCHLIST > $PATCHLISTID
    # count files listed in test_list_id_only.txt
    iterations=$(wc -w $PATCHLISTID  | grep -o "^[0-9]\+")
    caffe test -model=$PROTOTXT -weights=$CAFFEMOD -iterations $iterations -gpu 0

    mv $CNNOUT ${DATA}$size/res
done

#cd ..
#
# resample classifications to original patch size, move w/ to densecrf
# call resample.py <input dir> <resampled width> <resampled height> <output dir>
# only resamples *.mat files, 
# output name := basename + .dat, if input name = basename + _blob_0.mat 
#
rm -r $CRFINPUT &> /dev/null  || echo "densecrf input folder does not exist"
mkdir -p $CRFINPUT
touch ${CRFINPUT}filelist.txt
python2 ${SCRIPTS}resample.py ${DATA}/small/res $SWIDTH $SHEIGHT $CRFINPUT
python2 ${SCRIPTS}resample.py ${DATA}/medium/res $MWIDTH $MHEIGHT $CRFINPUT
python2 ${SCRIPTS}resample.py ${DATA}/large/res $LWIDTH $LHEIGHT $CRFINPUT

# move roi files to densecrf
rm -r $CRFROI &> /dev/null  || echo "roi folder does not exist"
mkdir -p $CRFROI
mv ${DATA}small/*.txt $CRFROI
mv ${DATA}medium/*.txt $CRFROI
mv ${DATA}large/*.txt $CRFROI

# move image to densecrf
cp $IMAGE $CRFIMAGE || echo "image already exists"

# run inference
#cd densecrf
mkdir -p $CRFRESULTS || echo "results folder already exists"
rm -r $CRFRESULTS/* || echo "results folder is empty"

PATCH_FILE="${CRFINPUT}filelist.txt"
RESULT_PATH="$CRFRESULTS"

wl=1 # weight for local CNN prediction term (large patches)
wm=1.7 # weight for local CNN prediction term (medium patches)
ws=1.7 # weight for local CNN prediction term (small patches)
sp=0.1 # stddev in the kernel

wi=12 # weight for inter-connected component term
df=0.6 # threshold for obtaining foreground map

wlocc=1.7 # weight for smoothness term
slocl=80 # spatial stddev
slocpr=0.2 # CNN prediction stddev

iters=15 # iterations of mean field to run

OUTPUT_FOLDER="${CRFRESULTS}/Results_wl${wl}_wm${wm}_ws${ws}_sp${sp}_wi${wi}_df${df}_wlocc${wlocc}_slocl${slocl}_slocpr${slocpr}_iters${iters}/"
mkdir -p ${OUTPUT_FOLDER}
#OUTPUT_FOLDER=$RESULT_PATH/

inference -p ${PATCH_FILE} -ws ${ws} -wm ${wm} -wl ${wl} -wi ${wi} -sp ${sp} -df ${df} -wc ${wc} -wp ${wp} -sps ${sps} -wcol ${wcol} -wlocc ${wlocc} -wlocp ${wlocp} -slocl ${slocl} -slocpr ${slocpr} -iters ${iters} -o ${OUTPUT_FOLDER}