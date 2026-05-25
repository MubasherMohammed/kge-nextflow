/*
 * DEMULTIPLEX module — BCL to FASTQ conversion
 *
 * Uses bcl-convert (Illumina) or bcl2fastq to convert raw BCL files
 * from an Illumina sequencer into demultiplexed FASTQ files.
 */

process DEMULTIPLEX {
    publishDir "${params.output_dir}/demultiplex", mode: 'copy'
    tag "${run_folder.baseName}"
    label 'demultiplex'

    input:
        path run_folder
        path sample_sheet

    output:
        path "fastq_output/**/*.fastq.gz", emit: fastqs
        path "fastq_output/**/*_Stats/**", emit: stats
        path "fastq_output/Logs/**", emit: logs

    script:
    """
    #! /usr/bin/env bash
    run_id=\$(basename "${run_folder}")

    if [ "${params.bcl_converter}" = "bcl-convert" ]; then
        echo "[DEMULTIPLEX] Running bcl-convert for run: \${run_id}"
        bcl-convert \\
            --input-dir "${run_folder}" \\
            --output-dir fastq_output \\
            --sample-sheet "${sample_sheet}" \\
            --no-lane-splitting \\
            --fastq-compression-level 6
    else
        echo "[DEMULTIPLEX] Running bcl2fastq for run: \${run_id}"
        bcl2fastq \\
            --runfolders-dir "${run_folder}" \\
            --output-dir fastq_output \\
            --sample-sheet "${sample_sheet}" \\
            --no-lane-splitting \\
            --use-bases-mask Y*,I8,Y*
    fi

    echo "[DEMULTIPLEX] Demultiplexing complete."
    find fastq_output -name "*.fastq.gz" | head -20
    """
}