#!/bin/bash

#SBATCH --time=3:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=10583M
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
masks=$(path $4)
evalscript=$(path $5)

mkdir -p ${Mfolder}

echo "cutting binary masks for images"
predictions=$(ls $PRfolder | wc | grep -o "^[^0-9]*[0-9]\+" | grep -o "[0-9]\+")
i=1

for prediction in ${PRfolder}*.png
do
    pname=$(basename $prediction | sed 's/.png//')
    python2 ${tools}tools/evalmasks.py $prediction 2048 1024 $Mfolder > ${Mfolder}${pname}.txt
    echo "done $i / $predictions"
    i=$(($i+1))
done

export CITYSCAPES_DATASET=$CSROOT
export CITYSCAPES_RESULTS=$Mfolder

python $evalscript > "$(basename $pred).performance"