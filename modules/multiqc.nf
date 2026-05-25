/*
 * MULTIQC module — Aggregate QC reports
 *
 * Collects FastQC, MAGeCK, and other QC outputs into a single
 * MultiQC HTML report.
 */

process MULTIQC_REPORT {
    publishDir "${params.output_dir}/multiqc", mode: 'copy'
    tag "multiqc"
    label 'multiqc'

    input:
        path qc_files

    output:
        path "multiqc_report.html", emit: report

    script:
    """
    #! /usr/bin/env bash
    echo "[MULTIQC] Aggregating QC reports..."

    # Create input directory for MultiQC
    mkdir -p qc_input
    cp -r ${qc_files} qc_input/ 2>/dev/null || true

    multiqc \\
        --force \\
        --outdir . \\
        --title "KGE CRISPR Screen QC Report" \\
        --filename multiqc_report.html \\
        qc_input/ 2>/dev/null || echo "[MULTIQC] MultiQC completed with warnings"

    echo "[MULTIQC] QC aggregation complete."
    """
}