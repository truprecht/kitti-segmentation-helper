#!/bin/bash

#SBATCH --time=2:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24
#SBATCH --mem-per-cpu=10583M
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

RAND="python ${TOOLS}tools/randn.py"
RESCALE="python ${TOOLS}tools/scale-labels.py"

# randomize parameters
wl=$("$RAND 1 0.2")     # weight for local CNN prediction term (large patches)
wm=$("$RAND 1.7 0.5")   # weight for local CNN prediction term (medium patches)
ws=$("$RAND 1.7 0.5")   # weight for local CNN prediction term (small patches)
sp=$("$RAND 0.1 0.02")  # stddev in the kernel

wi=$("$RAND 12 2")      # weight for inter-connected component term
df=$("$RAND 0.6 0.1")   # threshold for obtaining foreground map

wlocc=$("$RAND 1.7 0.5")    # weight for smoothness term
slocl=$("$RAND 80 10")      # spatial stddev
slocpr=$("$RAND 0.2 0.04")     # CNN prediction stddev
iters=50                    # iterations of mean field to run

CONFIG="inference-${wl}-${wm}-${ws}-${sp}-${wi}-${df}-${wlocc}-${slocl}-${slocpr}"

if [ -d "${OUT}${CONFIG}" ]; then
    echo "configuration already exists"
    exit 1
fi

mkdir -p "${OUT}${CONFIG}"

srun inference -p ${DATA}input/filelist.txt -ws ${ws} -wm ${wm} -wl ${wl} -wi ${wi} -sp ${sp} -df ${df} -wlocc ${wlocc} -slocl ${slocl} -slocpr ${slocpr} -iters ${iters} -o "${OUT}${CONFIG}"

for lbl in ${OUT}${CONFIG}/*
do
    $RESCALE $lbl 256 2048 1024 $lbl
done