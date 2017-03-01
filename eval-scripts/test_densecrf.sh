#!/bin/bash

#SBATCH --time=24:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=10583M
#SBATCH --mail-user=thomas.ruprecht@tu-dresden.de
#SBATCH --mail-type=END,FAIL

export OMP_NUM_THREADS=12


if [ -z $1 ]
then
    echo "use $0 <input folder> <scripts folder> [<output folder>]"
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
IMAGES=${ROOT}image.tar.gz
PATCHES=${ROOT}input.tar.gz
ROIS=${ROOT}roi.tar.gz

tar -xzf $IMAGES
tar -xzf $PATCHES
tar -xzf $ROIS

mkdir -p data/input
mv ${ROOT}image data/
mv ${ROOT}roi data/

PATCHES=data/input
IMAGES=data/image
ROIS=data/roi
LIST=${PATCHES}/filelist.txt

SCRIPTS=$(path $2)

if [ -z $3 ]
then
    OUT="CRFRESULT/"
else
    OUT=$(path $3)
fi


# run inference
mkdir -p $OUT


# resample classifications to original patch size, move w/ to densecrf
# call resample.py <input dir> <resampled width> <resampled height> <output dir>
# only resamples *.mat files, 
# output name := basename + .dat, if input name = basename + _blob_0.mat
for patchset in ${ROOT}input/*
do
    SWIDTH=275
    SHEIGHT=330

    MWIDTH=400
    MHEIGHT=500

    LWIDTH=600
    LHEIGHT=750

    touch $LIST

    if [ $patchset == *_small.png ]
    then
        echo "resampling small image $patchset" 
        python2 ${SCRIPTS}resample.py $patchset/small $(($SWIDTH/2)) $(($SHEIGHT/2)) $PATCHES
        python2 ${SCRIPTS}resample.py $patchset/medium $(($MWIDTH/2)) $(($MHEIGHT/2)) $PATCHES
        python2 ${SCRIPTS}resample.py $patchset/large $(($LWIDTH/2)) $(($LHEIGHT/2)) $PATCHES
    else
        echo "resapling image $patchset"
        python2 ${SCRIPTS}resample.py $patchset/small $SWIDTH $SHEIGHT $PATCHES
        python2 ${SCRIPTS}resample.py $patchset/medium $MWIDTH $MHEIGHT $PATCHES
        python2 ${SCRIPTS}resample.py $patchset/large $LWIDTH $LHEIGHT $PATCHES
    fi
    wl=1 # weight for local CNN prediction term (large patches)
    wm=1.7 # weight for local CNN prediction term (medium patches)
    ws=1.7 # weight for local CNN prediction term (small patches)
    sp=0.1 # stddev in the kernel

    wi=12 # weight for inter-connected component term
    df=0.6 # threshold for obtaining foreground map

    wlocc=1.7 # weight for smoothness term
    slocl=80 # spatial stddev
    slocpr=0.2 # CNN prediction stddev
    iters=50 # iterations of mean field to run

    echo "begin inference of $IMAGEFILTER $(date)" >> timelog.txt 
    srun inference -p $LIST -ws ${ws} -wm ${wm} -wl ${wl} -wi ${wi} -sp ${sp} -df ${df} -wc ${wc} -wp ${wp} -sps ${sps} -wcol ${wcol} -wlocc ${wlocc} -wlocp ${wlocp} -slocl ${slocl} -slocpr ${slocpr} -iters ${iters} -o $OUT
    echo "end inference of $IMAGEFILTER $(date)" >> timelog.txt 
    
    rm $PATCHES/*.dat $LIST
done