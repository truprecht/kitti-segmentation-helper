#!/bin/bash

#SBATCH --time=2:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24
#SBATCH --mem-per-cpu=2583M
#SBATCH --mail-user=thomas.ruprecht@tu-dresden.de
#SBATCH --mail-type=END,FAIL

export OMP_NUM_THREADS=24


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

DATA=$(path $1)
TOOLS=$(path $2)
if [ -z $3 ]; then OUT="./"; else OUT=$(path $3); fi

RAND="${TOOLS}tools/randn.py"
RESCALE="${TOOLS}tools/scale-labels.py"

# randomize parameters
wl=$(python $RAND 1 0.3)     # weight for local CNN prediction term (large patches)
wm=$(python $RAND 1.7 1)   # weight for local CNN prediction term (medium patches)
ws=$(python $RAND 1.7 1)   # weight for local CNN prediction term (small patches)
sp=$(python $RAND 0.1 0.05)  # stddev in the kernel

wi=$(python $RAND 12 6)      # weight for inter-connected component term
df=$(python $RAND 0.6 0.3)   # threshold for obtaining foreground map

wlocc=$(python $RAND 1.7 1)    # weight for smoothness term
slocl=$(python $RAND 80 20)      # spatial stddev
slocpr=$(python $RAND 0.2 0.1)     # CNN prediction stddev
iters=50                    # iterations of mean field to run

CONFIG="inference-${wl}-${wm}-${ws}-${sp}-${wi}-${df}-${wlocc}-${slocl}-${slocpr}"

if [ -d "${OUT}${CONFIG}" ]; then
    echo "configuration already exists"
    exit 1
fi

mkdir -p "${OUT}${CONFIG}"

srun inference -p ${DATA}input/filelist.txt -ws ${ws} -wm ${wm} -wl ${wl} -wi ${wi} -sp ${sp} -df ${df} -wlocc ${wlocc} -slocl ${slocl} -slocpr ${slocpr} -iters ${iters} -o "${OUT}${CONFIG}/"

for lbl in ${OUT}${CONFIG}/*
do
    python $RESCALE $lbl 256 2048 1024 $lbl
done