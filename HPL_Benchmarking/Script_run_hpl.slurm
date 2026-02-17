#!/bin/bash
#SBATCH --job-name=HPL_48Core_Test
#SBATCH --partition=debug
#SBATCH --nodes=3
#SBATCH --ntasks=48
#SBATCH --ntasks-per-node=16
#SBATCH --output=/Storage_cluster/Output_cluster/HPL_final_%j.out

# Move to the binary location
cd /Storage_cluster/hpl-2.3/bin/ubuntu/

# Force OpenBLAS to stay single-threaded per MPI task
export OPENBLAS_NUM_THREADS=1

# Execute the benchmark
mpirun ./xhpl
~                                                                                                                                                                                       
~               
