nextflow.enable.dsl=2
params.rawdata = params.rawdata ?: null
params.outdir       = params.outdir ?: null

// Validate required parameters at runtime
if (!params.rawdata) { error "Missing required parameter: --rawdata" }
if (!params.outdir)       { error "Missing required parameter: --outdir" }


// module load nextflow
// export NXF_VER=25.10.1
// nextflow run 1.staging.nf --rawdata RawData/R1/B1 --outdir TMA7_MCMICRO  -c nvwulf.config -resume --with-report report.html --with-timeline timeline.html

process MACSIMA2MC_NODE {
    tag "${sample_id}"
    executor 'slurm'
    queue 'b40x4'

    cpus 16
    memory '64 GB'
    time '4h'
    
    beforeScript 'source /lustre/nvwulf/software/miniconda3/etc/profile.d/conda.sh && conda activate macsima2mc && module load gnu-parallel/202260722'

    publishDir "${params.outdir}", mode: 'copy'

    input:
    tuple val(sample_id), path(sample_dir)

    output:
    path("${sample_id}"), emit: staged_output

    script:
    """
    mkdir -p "./${sample_id}"

    for cycle in "${sample_dir}"/*Cycle*; do
        if [ -d "\$cycle" ]; then
            macsima2mc -i "\$cycle" -o "./${sample_id}" -ic -he -qc
        fi
    done
    """
}

workflow {
    ch_samples = Channel
        .fromPath("${params.rawdata}/ROI*", type: 'dir')
        // Filter out ROI0, ROI00, or any path ending exactly with ROI0
        .filter { dir -> !dir.name.matches(/^ROI0+$/) }
        .map { dir ->
            // Extract numerical index from ROI name (e.g., ROI1 -> 1, ROI15 -> 15)
            def task_id   = (dir.name =~ /\d+/)[0]
            def sample_id = "${task_id}_${dir.name}"
            
            return tuple(sample_id, dir)
        }

    MACSIMA2MC_NODE(ch_samples)
}
