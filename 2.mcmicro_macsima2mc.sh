#!/usr/bin/bash

#SBATCH --job-name=macsima_test
#SBATCH --partition=b40x4-long
#SBATCH --time=24:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --array=1
#SBATCH --output=mcmicro_%A_%a.log
#SBATCH --mem=200gb

# sbatch 2.mcmicro_macsima2mc.sh /lustre/nvwulf/projects/ShroyerGroup-nvwulf/lyanne_results/TMA5/2.params.yml /lustre/nvwulf/projects/ShroyerGroup-nvwulf/lyanne_results/TMA5/TMA5_MCMICRO/2.samples.tsv /lustre/nvwulf/projects/ShroyerGroup-nvwulf/lyanne_results/0.nvwulf.config

# --- Argument Parsing ---
if [ "$#" -lt 2 ]; then
    echo "Error: Missing required arguments."
    echo "Usage: sbatch $0 <path_to_params.yml> <path_to_samples.tsv> [path_to_config]"
    exit 1
fi

# Convert input paths to absolute paths
params_file=$(readlink -f "$1")
array_config=$(readlink -f "$2")
config=$(readlink -f "${3:-/lustre/nvwulf/projects/ShroyerGroup-nvwulf/lyanne_results/0.nvwulf.config}")

# Validate file paths
for f in "$params_file" "$array_config" "$config"; do
    if [ ! -f "$f" ]; then
        echo "Error: File not found at '$f'"
        exit 1
    fi
done

# --- Environment Setup ---
export SINGULARITY_CACHEDIR="/lustre/nvwulf/scratch/$USER/singularity"
export NXF_SINGULARITY_CACHEDIR="/lustre/nvwulf/scratch/$USER/singularity"

module load nextflow
export NXF_VER=25.10.1

# --- Sample Identification ---
sample_entry=$(awk -v ArrayTaskID=$SLURM_ARRAY_TASK_ID '$1==ArrayTaskID {print $2}' "$array_config")

if [ -z "$sample_entry" ]; then
    echo "Error: No entry found for ArrayTaskID=$SLURM_ARRAY_TASK_ID in $array_config"
    exit 1
fi

# Convert sample path to an absolute path
sample=$(readlink -f "$sample_entry")
sample_dir=$(dirname "$sample")

# Define explicit, fixed directories for Nextflow caching per sample
work_directory="$sample_dir/work"

export NXF_ENTRY_POINT="$sample_dir"

# Force Nextflow to store execution history and session metadata inside the sample directory
cd "$sample_dir"

# --- Execution ---
nextflow run labsyspharm/mcmicro  -resume --in "$sample" --params "$params_file" -work-dir "$work_directory" -c "$config" --viz
