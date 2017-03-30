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
    echo "Use $0 <solver file> <initial weight file>"
    exit 1
fi

srun caffe train -solver=$1 -weights=$2 -gpu 0
