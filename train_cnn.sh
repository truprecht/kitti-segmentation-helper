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

function help(){
    echo "Use $0 <solver file> (init|snap) <solverstate / weights file> [<logfile>]"
}

if [ -z $1 ] || [ -z $2 ] || [ -z $3 ]; then
    echo $(help)
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

if [ "$2" == "init" ]; then
    srun caffe train -solver=$1 -weights=$3 -gpu 0 > "$logfile"
elif [ "$2" == "snap" ]; then
    srun caffe train -solver=$1 -snapshot=$3 -gpu 0 > "$logfile"
else
    echo $(help)
    exit 1
fi
