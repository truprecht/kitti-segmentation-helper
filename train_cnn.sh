#!/bin/bash

#SBATCH --time=60:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1 
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=6
#SBATCH --mem-per-cpu=3000M 
#SBATCH --mail-user=thomas.ruprecht@tu-dresden.de
#SBATCH --mail-type=END,FAIL

export OMP_NUM_THREADS=6

function path() {
    if [ "${1: -1}" != "/" ]
    then
        echo $1/
    else
        echo $1
    fi
}

if [ -z $1 ] || [ -z $2 ]; then
    echo "Use $0 <solver file> <initial weight file> [<solverstate>] [<logfile>]"
    exit 1
fi
if [ -z $4 ]; then
    logfile="caffe.log"
else
    logfile=$4
fi


if [ -e $logfile ]; then
    i=1
    while [ -e "$logfile.$i" ]; do
        i=$(($i + 1))
    done
    logfile="$logfile.$i"
fi

if [ -z $3 ]; then
    srun caffe train -solver=$1 -weights=$2 -gpu 0 > "$logfile"
else
    srun caffe train -solver=$1 -weights=$2 -snapshot=$3 -gpu 0 > "$logfile"
fi
