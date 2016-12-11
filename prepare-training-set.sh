#!/bin/bash
# execute in project root, expect subfolders ./cnn

if [ -z $1 ]
then
    echo "use $0 <image folder> <annotation folder> <output folder> <output list>"
    exit 1
fi

SWIDTH=275
SHEIGHT=330
SSTRIDE=50

MWIDTH=400
MHEIGHT=500
MSTRIDE=80

LWIDTH=600
LHEIGHT=750
LSTRIDE=120

rm $4
touch $4

for image in $1/*.png
do
    basename=$(echo $image | grep -o "^[^.]\+")
    annot=${basename}_gtFine_instanceTrainIds.png

    python2 patchesv2.py $1/$image $SWIDTH $SHEIGHT $SSTRIDE $LHEIGHT $3 _3 $2/$annot >> $4
    python2 patchesv2.py $1/$image $MWIDTH $MHEIGHT $MSTRIDE $LHEIGHT $3 _2 $2/$annot >> $4
    python2 patchesv2.py $1/$image $LWIDTH $LHEIGHT $LSTRIDE $LHEIGHT $3 _1 $2/$annot >> $4
done