#!/bin/bash
# execute in project root, expect subfolders ./cnn, ./densecrf
set -e

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

# cut image patches
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

    iterations=$(wc -w test_list_id_only.txt  | grep -o "^[0-9]\+")
    bash run_test.sh $iterations
    
    mv fc8_val3769 ../data/$size/res
done

cd ..
# resample classifications to original patch size, move w/ roi files to densecrf
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

# TODO: run inference
cd densecrf
bash RunInference.bash