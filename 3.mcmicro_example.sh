#!/bin/bash

#SBATCH --job-name=mcmicro_head
#SBATCH --partition=b40            # Requesting the b40 CPU partition
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2          # Orchestration doesn't need many cores
#SBATCH --mem=8G                   # Adjust based on workflow size
#SBATCH --time=08:00:00
#SBATCH --output=mcmicro_head_%j.log

# --- Environment Setup ---
export SINGULARITY_CACHEDIR=/lustre/nvwulf/scratch/$USER/singularity
export NXF_SINGULARITY_CACHEDIR=/lustre/nvwulf/scratch/$USER/singularity

module load nextflow
export NXF_VER=25.10.1

# --- Execution ---
# Note: Nextflow will now submit individual tasks to the GPU nodes 
# automatically if your 'nvwulf.config' is configured for SLURM.


# srun -p h200x8 --gres=gpu:1 --time=8:00:00 --pty bash

nextflow run labsyspharm/mcmicro/exemplar.nf --name exemplar-001 --path .

nextflow run labsyspharm/mcmicro/exemplar.nf --name exemplar-002 --path .

nextflow run labsyspharm/mcmicro \
    --in exemplar-002 \
    --tma \
    --viz \
    -profile singularity \
    -c 0.nvwulf.config

# TOTAL TIME: 17m29s

# Currently in development, not yet ready for use. Will be available in the near future.
# nextflow run nf-core/mcmicro  -profile seawulf \
# --input_cycle samplesheet.csv  --marker_sheet markers.csv --outdir test
