#!/bin/bash

#SBATCH --time=8:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24
#SBATCH --mem-per-cpu=10583M
#SBATCH --mail-user=thomas.ruprecht@tu-dresden.de
#SBATCH --mail-type=END,FAIL

export OMP_NUM_THREADS=12


if [ -z $1 ]
then
    echo "use $0 <file list> [<output folder>]"
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

LIST=$1
if [ -z $2 ]
then
    OUT="CRFRESULT/"
else
    OUT=$(path $2)
fi

# run inference
rm -r $OUT
mkdir -p $OUT

wl=1 # weight for local CNN prediction term (large patches)
wm=1.7 # weight for local CNN prediction term (medium patches)
ws=1.7 # weight for local CNN prediction term (small patches)
sp=0.1 # stddev in the kernel

wi=12 # weight for inter-connected component term
df=0.6 # threshold for obtaining foreground map

wlocc=1.7 # weight for smoothness term
slocl=80 # spatial stddev
slocpr=0.2 # CNN prediction stddev
iters=50 # iterations of mean field to run

inference -p $LIST -ws ${ws} -wm ${wm} -wl ${wl} -wi ${wi} -sp ${sp} -df ${df} -wc ${wc} -wp ${wp} -sps ${sps} -wcol ${wcol} -wlocc ${wlocc} -wlocp ${wlocp} -slocl ${slocl} -slocpr ${slocpr} -iters ${iters} -o $OUT