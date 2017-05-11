#!/bin/bash

#SBATCH --time=3:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24
#SBATCH --mem-per-cpu=2583M
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
    echo "use $0 <prediction folder>"
fi

pred=$(path $1)
find ${pred} -name "*.png" | sort | paste - testset.annot > /tmp/annots
python kitti-segmentation-helper/eval-scripts/eval-instantiation.py /tmp/annots 24 > "$(basename $pred).performance"

rm /tmp/annots

