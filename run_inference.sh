#!/bin/bash

#SBATCH --time=24:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24
#SBATCH --mem-per-cpu=2583M
#SBATCH --mail-user=thomas.ruprecht@tu-dresden.de
#SBATCH --mail-type=END,FAIL

export OMP_NUM_THREADS=24


if [ -z $1 ]
then
    echo "use $0 <input folder> [<output folder>]"
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

ROOT=$(path $1)
TMP="/tmp/"

IMAGES=${ROOT}image.tar.gz
PATCHES=${ROOT}input.tar.gz
ROIS=${ROOT}roi.tar.gz

tar -C "/" -xzf $IMAGES
tar -C "/" -xzf $PATCHES
tar -C "/" -xzf $ROIS

PATCHES=${TMP}input
IMAGES=${TMP}image
ROIS=${TMP}roi
LIST=${PATCHES}/filelist.txt

SCRIPTS="kitti-segmentation-helper/"

if [ -z $2 ]
then
    OUT="CRFRESULT/"
else
    OUT=$(path $2)
fi


# resample classifications to original patch size, move w/ to densecrf
# call resample.py <input dir> <resampled width> <resampled height> <output dir>
# only resamples *.mat files, 
# output name := basename + .dat, if input name = basename + _blob_0.mat

SWIDTH=275
SHEIGHT=330

MWIDTH=400
MHEIGHT=500

LWIDTH=600
LHEIGHT=750

touch $LIST

python2 ${SCRIPTS}tools/resample.py $PATCHES/small $(($SWIDTH/2)) $(($SHEIGHT/2)) $PATCHES
python2 ${SCRIPTS}tools/resample.py $PATCHES/medium $(($MWIDTH/2)) $(($MHEIGHT/2)) $PATCHES
python2 ${SCRIPTS}tools/resample.py $PATCHES/large $(($LWIDTH/2)) $(($LHEIGHT/2)) $PATCHES

for im in $IMAGES/*
do
    python2 ${SCRIPTS}tools/scale-image.py $im 1024 512 $im
done
for roi in $ROIS/*
do
    if [[ $roi == *_1_*.txt ]]
    then
        python2 ${SCRIPTS}tools/scale-roi.py $roi $(($LWIDTH/4)) $(($LHEIGHT/4))
    elif [[ $roi == *_2_*.txt ]]
    then
        python2 ${SCRIPTS}tools/scale-roi.py $roi $(($MWIDTH/4)) $(($MHEIGHT/4))
    elif [[ $roi == *_3_*.txt ]]
    then
        python2 ${SCRIPTS}tools/scale-roi.py $roi $(($SWIDTH/4)) $(($SHEIGHT/4))
    fi
done

# run inference
mkdir -p $OUT

# 0.09-1.62-1.63-0.08-20.5-0.67-1.18-85.67-0.19

wl=0.09 # weight for local CNN prediction term (large patches)
wm=1.62 # weight for local CNN prediction term (medium patches)
ws=1.63 # weight for local CNN prediction term (small patches)
sp=0.08 # stddev in the kernel

wi=20.5 # weight for inter-connected component term
df=0.67 # threshold for obtaining foreground map

wlocc=1.18 # weight for smoothness term
slocl=85.67 # spatial stddev
slocpr=0.19 # CNN prediction stddev
iters=50 # iterations of mean field to run

srun inference -p $LIST -ws ${ws} -wm ${wm} -wl ${wl} -wi ${wi} -sp ${sp} -df ${df} -wc ${wc} -wp ${wp} -sps ${sps} -wcol ${wcol} -wlocc ${wlocc} -wlocp ${wlocp} -slocl ${slocl} -slocpr ${slocpr} -iters ${iters} -o $OUT

rm -r $PATCHES $IMAGES $ROIS

for lbl in ${OUT}*
do
    python2 ${SCRIPTS}tools/scale-labels.py $lbl 512 2048 1024 $lbl
done