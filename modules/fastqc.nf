/*
 * FASTQC module — Pre-alignment quality control
 *
 * Runs FastQC on input FASTQ files and emits HTML/zip reports.
 */

process FASTQC_READS {
    publishDir "${params.output_dir}/fastqc", mode: 'copy'
    tag "${fastq.baseName}"
    label 'fastqc'

    input:
        path fastq

    output:
        path "*_fastqc.html", emit: html
        path "*_fastqc.zip", emit: zips

    script:
    """
    #! /usr/bin/env bash
    echo "[FASTQC] Running FastQC on: ${fastq}"
    fastqc \\
        --threads ${task.cpus} \\
        --outdir . \\
        --quiet \\
        "${fastq}"
    """
}