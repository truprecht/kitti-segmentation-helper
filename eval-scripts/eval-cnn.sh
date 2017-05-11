#!/bin/bash

#SBATCH --time=3:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:1
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
    echo "use $0 <annotated patch list>"
fi

TMP="/tmp"
WEIGHTS="cnn/cityscapes.caffemodel"
PROTOTXT="cnn/test.caffemodel"
CAFFEOUT="$TMP/fc8_val3769/"
LIST="test_list.txt"
LIST_IDS="test_list_id_only.txt"

cat $1 | awk '{print $1}' > $LIST
cat $LIST | sed 's:^.*/::' | sed 's:.png::' > $LIST_IDS

srun caffe test --weights="$WEIGHTS" --model="$PROTOTXT" --gpu=0

cat $1 | awk '{print $2}' > "/tmp/annots"
cat $LIST_IDS | sed "s:^:$CAFFEOUT:" | sed 's:$:_blob_0.mat:' | paste - "/tmp/annots" > "/tmp/annots.1"

python kitti-segmentation-helper/eval-scripts/eval-instantiation.py "/tmp/annots.1" 6

rm -r "/tmp/fc8_val3769/"
rm "/tmp/annots" "/tmp/annots.1"