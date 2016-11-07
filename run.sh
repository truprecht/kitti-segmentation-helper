#!/bin/bash
# execute in project root, expect subfolders ./cnn, ./densecrf
set -e

if [ -z $1 ]
then
    echo "use $0 <image file>"
    exit 1
fi

IMAGE=$1

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
rm -r data &> /dev/null || echo "data folder does not exist"
mkdir data
cd cnn
python2 ../patches.py ../$IMAGE $SWIDTH $SHEIGHT $SSTRIDE $LHEIGHT ../data/small "_3"
python2 ../patches.py ../$IMAGE $MWIDTH $MHEIGHT $MSTRIDE $LHEIGHT ../data/medium "_2"
python2 ../patches.py ../$IMAGE $LWIDTH $LHEIGHT $LSTRIDE $LHEIGHT ../data/large "_1"

# run cnn test on different patch sizes seperately, move 'em to data folder
for size in small medium large
do
    rm -r fc8_val3769 &> /dev/null || echo "output folder does not exist"
    mkdir fc8_val3769
    
    (rm test_list.txt &> /dev/null; rm test_list_id_only.txt &> /dev/null)  || echo "id lists do not exist"
    cp ../data/$size/*.txt ./

    # count files listed in test_list_id_only.txt
    iterations=$(wc -w test_list_id_only.txt  | grep -o "^[0-9]\+")
    caffe test -model=test.prototxt -weights=deeplab-kitti-60k.caffemodel -iterations $iterations -gpu 0

    mv fc8_val3769 ../data/$size/res
done

cd ..
#
# resample classifications to original patch size, move w/ to densecrf
# call resample.py <input dir> <resampled width> <resampled height> <output dir>
# only resamples *.mat files, 
# output name := basename + .dat, if input name = basename + _blob_0.mat 
#
rm -r densecrf/data/input &> /dev/null  || echo "densecrf input folder does not exist"
mkdir densecrf/data/input
touch densecrf/data/input/filelist.txt
python2 resample.py data/small/res $SWIDTH $SHEIGHT densecrf/data/input
python2 resample.py data/medium/res $MWIDTH $MHEIGHT densecrf/data/input
python2 resample.py data/large/res $LWIDTH $LHEIGHT densecrf/data/input

# move roi files to densecrf
rm -r densecrf/data/roi &> /dev/null  || echo "roi folder does not exist"
mkdir densecrf/data/roi
mv data/small/roi/* densecrf/data/roi/
mv data/medium/roi/* densecrf/data/roi/
mv data/large/roi/* densecrf/data/roi/

# move image to densecrf
cp $IMAGE densecrf/data/image/

# run inference
cd densecrf
bash RunInference.bash