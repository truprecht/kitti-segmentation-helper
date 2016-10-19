#!/bin/bash
# execute in project root, expect subfolders ./cnn, ./densecrf

IMAGE = "..."
SWIDTH = 50
SHEIGHT = 50
MWIDTH = 75
MHEIGHT = 75
LWIDTH = 100
LHEIGHT = 100
STRIDE = 20

# cut image patches
rm -r data && echo "clearing data folder"
mkdir data && mkdir data/small && mkdir data/medium && mkdir data/large
cd cnn
python2 ../patches.py $IMAGE $SWIDTH $SHEIGHT $STRIDE ../data/small s
python2 ../patches.py $IMAGE $MWIDTH $MHEIGHT $STRIDE ../data/medium m
python2 ../patches.py $IMAGE $LWIDTH $LHEIGHT $STRIDE ../data/large l

# run cnn test on different patch sizes seperately, move 'em to data folder
for size in small medium large
do
    (rm test_list.txt; rm test_list_id_only.txt) && echo "clearing test list"
    cp ../data/$size/*.txt ./

    rm -r fc8_blahblah && echo "clearing output folder"
    mkdir fc8_blahblah
    bash run_test.sh
    mv fc8_blahblah ../data/$size/res
end

cd ..
# resample classifications to original patch size, move w/ roi files to densecrf
rm -r densecrf/data/input && echo "clearing densecrf input folder"
mkdir densecrf/data/input
python2 resample.py data/small/res $SWIDTH $SHEIGHT data/results
python2 resample.py data/medium/res $MWIDTH $MHEIGHT data/results
python2 resample.py data/large/res $LWIDTH $LHEIGHT data/results

# move roi files to densecrf
rm -r densecrf/data/roi && echo "clearing roi files"
mkdir densecrf/data/roi
mv data/small/roi/* densecrf/data/roi/
mv data/medium/roi/* densecrf/data/roi/
mv data/large/roi/* densecrf/data/roi/

# TODO: run inference
