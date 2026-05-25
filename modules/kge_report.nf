/*
 * KGE REPORT module — Interactive Plotly HTML Report Generation
 *
 * Runs `mageck report` using the KGE-enhanced MAGeCK with interactive
 * Plotly charts, dynamic gene tables, pathway enrichment, and
 * FLUTE-style gene classification.
 *
 * This module auto-detects RRA and/or MLE gene summaries and generates
 * a comprehensive self-contained HTML report.
 */

process KGE_REPORT {
    tag "${prefix}"
    label 'kge_report'

    input:
        path count_table
        path count_normalized
        path count_summary
        path rra_gene_summaries
        path rra_sgrna_summaries
        path mle_gene_summaries
        path mle_sgrna_summaries
        path design_matrix
        val params_obj

    output:
        path "${prefix}.report.html",    emit: html_report
        path "${prefix}_report_data/",  emit: report_data

    script:
    prefix = params_obj.output_prefix ?: 'mageck'
    """
    #! /usr/bin/env bash
    echo "[KGE_REPORT] Generating interactive HTML report..."

    # Create a working directory with all the input files
    WORKDIR="report_work"
    mkdir -p "\${WORKDIR}"

    # Copy count table
    cp "${count_table}" "\${WORKDIR}/"

    # Copy normalized counts if available
    if [ -f "${count_normalized}" ]; then
        cp "${count_normalized}" "\${WORKDIR}/"
    fi

    # Copy count summary if available
    if [ -f "${count_summary}" ]; then
        cp "${count_summary}" "\${WORKDIR}/"
    fi

    # Copy RRA gene summaries
    for f in ${rra_gene_summaries}; do
        if [ -f "\${f}" ]; then
            cp "\${f}" "\${WORKDIR}/"
        fi
    done

    # Copy RRA sgRNA summaries
    for f in ${rra_sgrna_summaries}; do
        if [ -f "\${f}" ]; then
            cp "\${f}" "\${WORKDIR}/"
        fi
    done

    # Copy MLE gene summaries
    for f in ${mle_gene_summaries}; do
        if [ -f "\${f}" ]; then
            cp "\${f}" "\${WORKDIR}/"
        fi
    done

    # Copy MLE sgRNA summaries
    for f in ${mle_sgrna_summaries}; do
        if [ -f "\${f}" ]; then
            cp "\${f}" "\${WORKDIR}/"
        fi
    done

    # Build optional arguments for the report command
    OPT_ARGS=""

    # Gene summary files (auto-detect from working dir if not specified)
    GENE_SUMMARY_ARGS=""
    for f in \${WORKDIR}/*.gene_summary.txt; do
        if [ -f "\${f}" ]; then
            GENE_SUMMARY_ARGS="\${GENE_SUMMARY_ARGS} \${f}"
        fi
    done
    if [ -n "\${GENE_SUMMARY_ARGS}" ]; then
        OPT_ARGS="\${OPT_ARGS} --gene-summary \${GENE_SUMMARY_ARGS}"
    fi

    # sgRNA summary files
    SGRNA_SUMMARY_ARGS=""
    for f in \${WORKDIR}/*.sgrna_summary.txt; do
        if [ -f "\${f}" ]; then
            SGRNA_SUMMARY_ARGS="\${SGRNA_SUMMARY_ARGS} \${f}"
        fi
    done
    if [ -n "\${SGRNA_SUMMARY_ARGS}" ]; then
        OPT_ARGS="\${OPT_ARGS} --sgrna-summary \${SGRNA_SUMMARY_ARGS}"
    fi

    # Design matrix (for MLE reports)
    if [ -f "${design_matrix}" ]; then
        OPT_ARGS="\${OPT_ARGS} --design-matrix ${design_matrix}"
    fi

    # Enrichment options
    if [ "${params_obj.skip_enrichment}" = "true" ] || [ "${params_obj.skip_enrichment}" = true ]; then
        OPT_ARGS="\${OPT_ARGS} --skip-enrichment"
    else
        OPT_ARGS="\${OPT_ARGS} --enrichment-top-n ${params_obj.enrichment_top_n}"
        OPT_ARGS="\${OPT_ARGS} --enrichment-fdr ${params_obj.enrichment_fdr}"
    fi

    # Organism
    if [ "${params_obj.organism}" != "human" ]; then
        OPT_ARGS="\${OPT_ARGS} --organism ${params_obj.organism}"
    fi

    # FDR threshold and top-N
    OPT_ARGS="\${OPT_ARGS} --fdr-threshold ${params_obj.fdr_threshold}"
    OPT_ARGS="\${OPT_ARGS} --top-n ${params_obj.top_n}"

    # Find the count table in the work dir
    COUNT_TABLE_IN_WORK=\$(ls \${WORKDIR}/*.count.txt 2>/dev/null | head -1)

    echo "[KGE_REPORT] Running: mageck report -n ${prefix} -k \${COUNT_TABLE_IN_WORK} \${OPT_ARGS}"

    # Run the report from within the work directory so auto-detection works
    cd "\${WORKDIR}"
    mageck report \\
        -n "${prefix}" \\
        -k "\${COUNT_TABLE_IN_WORK}" \\
        \${OPT_ARGS}
    cd ..

    # Copy output
    cp "\${WORKDIR}/${prefix}.report.html" . 2>/dev/null || true

    # Collect report data
    mkdir -p "${prefix}_report_data"
    cp "\${WORKDIR}/"*.gene_summary.txt "${prefix}_report_data/" 2>/dev/null || true
    cp "\${WORKDIR}/"*.sgrna_summary.txt "${prefix}_report_data/" 2>/dev/null || true
    cp "\${WORKDIR}/"*.log "${prefix}_report_data/" 2>/dev/null || true
    cp "\${WORKDIR}/"*.count.txt "${prefix}_report_data/" 2>/dev/null || true
    cp "\${WORKDIR}/"*.count_normalized.txt "${prefix}_report_data/" 2>/dev/null || true
    cp "\${WORKDIR}/"*.countsummary.txt "${prefix}_report_data/" 2>/dev/null || true

    echo "[KGE_REPORT] Report generation complete."
    ls -la ${prefix}.report.html 2>/dev/null || echo "Warning: HTML report not found"
    """
}