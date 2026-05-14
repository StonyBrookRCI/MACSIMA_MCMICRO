#!/usr/bin/bash

#SBATCH --job-name=macsima_test
#SBATCH --partition=b40x4-long            # Requesting the b40 CPU partition
#SBATCH --time=24:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --array=1-55
#SBATCH --output=mcmicro_head_%j.log
#SBATCH --mem=200gb

# --- Execution ---
# Note: Nextflow will now submit individual tasks to the GPU nodes 
# automatically if your 'nvwulf.config' is configured for SLURM.
# sbatch mcmicro_macsima2mc.sh


# srun -p h200x8 --gres=gpu:1 --time=8:00:00 --pty bash

# --- Environment Setup ---

export SINGULARITY_CACHEDIR=/lustre/nvwulf/scratch/$USER/singularity
export NXF_SINGULARITY_CACHEDIR=/lustre/nvwulf/scratch/$USER/singularity

module load nextflow
export NXF_VER=25.10.1

params_file="/lustre/nvwulf/projects/CarlsonGroup-nvwulf/agilgomez/params.yml"
array_config="/lustre/nvwulf/projects/CarlsonGroup-nvwulf/agilgomez/samples.tsv"
config="/lustre/nvwulf/projects/CarlsonGroup-nvwulf/agilgomez/nvwulf.config"

sample=$(awk -v ArrayTaskID=$SLURM_ARRAY_TASK_ID '$1==ArrayTaskID {print $2}' $array_config)

nextflow run labsyspharm/mcmicro --in ${sample} \
 --params $params_file -with-report ${sample}.html -resume -c $config --viz





 