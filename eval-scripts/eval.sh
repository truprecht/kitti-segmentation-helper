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

cs=$(path $1)
tools=$(path $2)
pred=$(path $3)
evalscript=$4

masks="temp/masks-$(basename $pred)/"

mkdir -p ${masks}

echo "cutting binary masks for images"
predictions=$(ls $pred | wc | grep -o "^[^0-9]*[0-9]\+" | grep -o "[0-9]\+")
i=1

for prediction in ${pred}*.png
do
    pname=$(basename $prediction | sed 's/.png//')
    python2 ${tools}tools/evalmasks.py $prediction 2048 1024 $masks > ${masks}${pname}.txt &
    echo "started $i / $predictions"
    i=$(($i+1))
done

echo "waiting $(date)..."
wait
echo "done $(date)"

export CITYSCAPES_DATASET=$cs
export CITYSCAPES_RESULTS=$masks

python $evalscript > "$(basename $pred).performance"

rm -r $masks