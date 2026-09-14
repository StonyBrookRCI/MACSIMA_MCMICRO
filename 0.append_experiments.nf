nextflow.enable.dsl=2


// Example run:
// nextflow run 0.append_experiments.nf -resume --inputs '/lustre/nvwulf/projects/DamaghiGroup-nvwulf/jowana_rawdata/DCIS_S18-5236_JO_1and2_appended/DCIS_S18-5236_JO_1_250321_391324/DCIS_S18-5236_JO_1_2025-03-19_14-20-18/RawData,/lustre/nvwulf/projects/DamaghiGroup-nvwulf/jowana_rawdata/DCIS_S18-5236_JO_1and2_appended/DCIS_S18-5236_JO_2_250324_120927/DCIS_S18-5236_JO_2_2025-03-21_12-27-07/RawData' --output '/lustre/nvwulf/projects/DamaghiGroup-nvwulf/jowana_rawdata/DCIS_S18-5236_JO_1and2_appended/RawData' -c 0.nvwulf.config



// ============================================================================
// Parameters
// ============================================================================

params.inputs = null
params.output = null


if (!params.inputs) {
    error """
Missing --inputs

Example:
  --inputs '/path/Experiment1/RawData,/path/Experiment2/RawData'
"""
}


if (!params.output) {
    error """
Missing --output

Example:
  --output '/path/Appended/RawData'
"""
}


// ============================================================================
// Convert comma-separated input string into a Groovy list
// ============================================================================

def input_dirs = params.inputs
    .split(',')
    .collect { it.trim() }
    .findAll { it }


if (input_dirs.size() < 2) {
    error "At least two input RawData directories are required."
}


// ============================================================================
// Validate input directories
// ============================================================================

input_dirs.each { dir ->

    def f = new File(dir)

    if (!f.exists() || !f.isDirectory()) {
        error "Input RawData directory does not exist:\n  ${dir}"
    }
}


// ============================================================================
// Validate output
//
// We deliberately do this before starting the workflow.
// This prevents accidentally mixing results from different runs.
// ============================================================================

def output_dir = new File(params.output)

if (output_dir.exists()) {
    log.warn """
Output directory already exists:

    ${params.output}

The workflow will continue and may overwrite existing files.
"""
}

// ============================================================================
// Find ROIs
//
// ROI0 is excluded.
//
// Example:
//   R1/A1/ROI1
//   R1/A1/ROI2
//   R1/A1/ROI10
// ============================================================================

def first_input = new File(input_dirs[0])

def roi_dirs = []


first_input.eachFileRecurse { f ->

    if (f.isDirectory() &&
        f.name ==~ /ROI[0-9]+/ &&
        f.name != 'ROI0') {

        def relative = first_input.toPath()
            .relativize(f.toPath())
            .toString()

        roi_dirs << relative
    }
}


roi_dirs = roi_dirs.unique().sort()


if (roi_dirs.isEmpty()) {
    error """
No usable ROI directories were found in:

  ${input_dirs[0]}

ROI0 is excluded by design.
"""
}


// ============================================================================
// Print summary
// ============================================================================

println ""
println "============================================================"
println "MACSima RawData append"
println "============================================================"
println ""

println "Input experiments:"

input_dirs.eachWithIndex { dir, i ->
    println "  ${i + 1}: ${dir}"
}

println ""
println "Output:"
println "  ${params.output}"

println ""
println "ROIs discovered (ROI0 excluded):"

roi_dirs.each {
    println "  ${it}"
}

println ""
println "Total ROI tasks: ${roi_dirs.size()}"
println "Parallelizing by ROI."
println "============================================================"
println ""



// ============================================================================
// ROI channel
// ============================================================================

Channel
    .fromList(roi_dirs)
    .set { roi_ch }



// ============================================================================
// APPEND_ROI
// ============================================================================

process APPEND_ROI {

    tag "${roi}"

    executor 'slurm'

    queue 'b40x4'

    cpus 2
    memory '64 GB'
    time '8h'


    // ------------------------------------------------------------------------
    // Publish the completed ROI to the final output directory.
    //
    // "link" creates a hard link rather than copying the files.
    //
    // Therefore:
    //
    //   work/.../R1/A1/ROI1/file.tif
    //              |
    //              +---- hard link ----> output/R1/A1/ROI1/file.tif
    //
    // Deleting the Nextflow work directory does NOT delete the published
    // file because the published filename is another hard link to the same
    // inode.
    // ------------------------------------------------------------------------

    publishDir "${params.output}",
        mode: 'link',
        overwrite: false


    input:

    val roi


    // ------------------------------------------------------------------------
    // The actual ROI directory is the process output.
    //
    // Because "roi" is something like:
    //
    //   R1/A1/ROI1
    //
    // publishDir will produce:
    //
    //   ${params.output}/R1/A1/ROI1
    // ------------------------------------------------------------------------

    output:

    path "${roi}"

script:
def bash_inputs = input_dirs
    .collect { "'${it.replace("'", "'\\''")}'" }
    .join(' ')

"""
set -euo pipefail

INPUT_DIRS=($bash_inputs)

ROI="${roi}"
DEST_ROI="\$ROI"

echo "=========================================="
echo "Processing ROI: \$ROI"
echo "Output: \$DEST_ROI"
echo "=========================================="

mkdir -p "\$DEST_ROI"

LAST_CYCLE=0
EXPERIMENT=0

for INPUT in "\${INPUT_DIRS[@]}"; do

    ((EXPERIMENT+=1))

    echo
    echo "------------------------------------------------------------"
    echo "Experiment \$EXPERIMENT"
    echo "------------------------------------------------------------"

    SOURCE_ROI="\$INPUT/\$ROI"

    if [[ ! -d "\$SOURCE_ROI" ]]; then
        echo "ERROR: ROI directory does not exist:"
        echo "  \$SOURCE_ROI"
        exit 1
    fi

    mapfile -t CYCLE_DIRS < <(
        find "\$SOURCE_ROI" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -regextype posix-extended \
            -regex '.*/[0-9]+_Cycle[0-9]+' |
        sort -V
    )

    if [[ \${#CYCLE_DIRS[@]} -eq 0 ]]; then
        echo "ERROR: No cycle directories found in:"
        echo "  \$SOURCE_ROI"
        exit 1
    fi

    for CYCLE_DIR in "\${CYCLE_DIRS[@]}"; do

        CYCLE_BASENAME="\$(basename "\$CYCLE_DIR")"

        if [[ "\$CYCLE_BASENAME" =~ ^([0-9]+)_Cycle([0-9]+)\$ ]]; then
            ORIGINAL_CYCLE="\${BASH_REMATCH[2]}"
        else
            echo "ERROR: Cannot parse cycle directory:"
            echo "  \$CYCLE_DIR"
            exit 1
        fi

        if [[ \$EXPERIMENT -eq 1 ]]; then
            NEW_CYCLE="\$ORIGINAL_CYCLE"
        else
            ((NEW_CYCLE=LAST_CYCLE+1))
        fi

        printf -v NEW_CYCLE_DIR "%d_Cycle%d" "\$NEW_CYCLE" "\$NEW_CYCLE"

        DEST_CYCLE="\$DEST_ROI/\$NEW_CYCLE_DIR"

        mkdir -p "\$DEST_CYCLE"

        echo "  \$CYCLE_BASENAME -> \$NEW_CYCLE_DIR"

        while IFS= read -r -d '' FILE; do

            REL_FILE="\${FILE#"\$CYCLE_DIR"/}"
            REL_DIR="\$(dirname "\$REL_FILE")"

            DEST_DIR="\$DEST_CYCLE/\$REL_DIR"
            mkdir -p "\$DEST_DIR"

            BASENAME="\$(basename "\$FILE")"
            DEST_BASENAME="\$BASENAME"

            if [[ "\$BASENAME" =~ \\.tif(f)?\$ ]]; then

                if [[ "\$BASENAME" =~ ^CYC-[0-9]+(.*)\$ ]]; then

                    SUFFIX="\${BASH_REMATCH[1]}"

                    printf -v NEW_CYC_NAME "CYC-%03d" "\$NEW_CYCLE"

                    DEST_BASENAME="\${NEW_CYC_NAME}\${SUFFIX}"

                else
                    echo "ERROR: TIFF does not start with CYC-###:"
                    echo "  \$FILE"
                    exit 1
                fi
            fi

            DEST_FILE="\$DEST_DIR/\$DEST_BASENAME"

            ln "\$FILE" "\$DEST_FILE"

        done < <(find "\$CYCLE_DIR" -type f -print0)

        LAST_CYCLE="\$NEW_CYCLE"

    done
done

echo
echo "Finished ROI: \$ROI"
"""
}



// ============================================================================
// Workflow
// ============================================================================

workflow {

    APPEND_ROI(roi_ch)

}