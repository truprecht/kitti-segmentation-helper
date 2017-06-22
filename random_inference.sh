#!/bin/bash

#SBATCH --time=4:00:00
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

DATA=$(path $1)
TOOLS="kitti-segmentation-helper"
if [ -z $2 ]; then OUT="./"; else OUT=$(path $2); fi

RAND="${TOOLS}/tools/rand.py"
RESCALE="${TOOLS}/tools/scale-labels.py"

cp -r "${DATA}input" "/tmp/"
cp -r "${DATA}image" "/tmp/"
cp -r "${DATA}roi" "/tmp/"

# randomize parameters
wl=$(python $RAND 2)     # weight for local CNN prediction term (large patches)
wm=$(python $RAND 2)   # weight for local CNN prediction term (medium patches)
ws=$(python $RAND 2)   # weight for local CNN prediction term (small patches)
sp=$(python $RAND 0.5)  # stddev in the kernel

wi=$(python $RAND 20)      # weight for inter-connected component term
df=$(python $RAND 1)   # threshold for obtaining foreground map

wlocc=$(python $RAND 2)    # weight for smoothness term
slocl=$(python $RAND 100)      # spatial stddev
slocpr=$(python $RAND 1)     # CNN prediction stddev
iters=50                    # iterations of mean field to run

CONFIG="inference-${wl}-${wm}-${ws}-${sp}-${wi}-${df}-${wlocc}-${slocl}-${slocpr}"

if [ -d "${OUT}${CONFIG}" ]; then
    echo "configuration already exists"
    exit 1
fi

mkdir -p "${OUT}${CONFIG}"

srun inference -p "/tmp/input/filelist.txt" -ws ${ws} -wm ${wm} -wl ${wl} -wi ${wi} -sp ${sp} -df ${df} -wlocc ${wlocc} -slocl ${slocl} -slocpr ${slocpr} -iters ${iters} -o "${OUT}${CONFIG}/"

for lbl in ${OUT}${CONFIG}/*
do
    python $RESCALE $lbl 512 2048 1024 $lbl
done