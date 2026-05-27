#!/usr/bin/bash
#SBATCH --job-name=b40x4
#SBATCH --partition=b40x4
#SBATCH --time=8:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --array=1-28

#INPUTS
acquisitions=/lustre/nvwulf/projects/CarlsonGroup-nvwulf/agilgomez/acquisitions.tsv
output_dir=/lustre/nvwulf/projects/CarlsonGroup-nvwulf/agilgomez/TMA/TMA_PDAC_EMT_07082025_1_tma1_2_260307_080108_MCMICRO
#END INPUTS

module load miniconda/3
source /lustre/nvwulf/software/miniconda3/etc/profile.d/conda.sh
conda activate macsima2mc

sample=$(awk -v ArrayTaskID=$SLURM_ARRAY_TASK_ID '$1==ArrayTaskID {print $2}' $acquisitions)

for cycle in $sample/*Cycle*; do
    sample_id=${SLURM_ARRAY_TASK_ID}
    sample_id+="_$(basename $sample)"
    echo "Processing: $cycle for Sample: $sample_id"

    macsima2mc -i $cycle -o $output_dir/$sample_id -ic -he -qc
    echo "Finished $cycle"
done
