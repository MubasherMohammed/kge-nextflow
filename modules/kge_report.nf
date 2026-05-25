/*
 * KGE REPORT module — Interactive Plotly HTML Report Generation
 *
 * Runs `mageck report` using the KGE-enhanced MAGeCK with interactive
 * Plotly charts, dynamic gene tables, pathway enrichment, and
 * FLUTE-style gene classification.
 *
 * Handles both full pipeline (with normalized counts + QC) and
 * count-table-only mode (where those files may be absent).
 */

process KGE_REPORT {
    publishDir "${params.output_dir}/kge_report", mode: 'copy'
    tag "${prefix}"
    label 'kge_report'

    input:
        path count_table
        path rra_gene_summaries
        path rra_sgrna_summaries
        path mle_gene_summaries
        path mle_sgrna_summaries
        path design_matrix
        val params_obj

    output:
        path "${prefix}.report.html",    emit: html_report
        path "${prefix}_report_data/", emit: report_data

    script:
    prefix = params_obj.output_prefix ?: 'mageck'
    """
    #! /usr/bin/env bash
    echo "[KGE_REPORT] Generating interactive HTML report..."

    WORKDIR="report_work"
    mkdir -p "\${WORKDIR}"

    cp "${count_table}" "\${WORKDIR}/"

    for f in ${rra_gene_summaries}; do
        [ -f "\${f}" ] && cp "\${f}" "\${WORKDIR}/"
    done

    for f in ${rra_sgrna_summaries}; do
        [ -f "\${f}" ] && cp "\${f}" "\${WORKDIR}/"
    done

    for f in ${mle_gene_summaries}; do
        [ -f "\${f}" ] && cp "\${f}" "\${WORKDIR}/"
    done

    for f in ${mle_sgrna_summaries}; do
        [ -f "\${f}" ] && cp "\${f}" "\${WORKDIR}/"
    done

    if [ -f "${design_matrix}" ]; then
        cp "${design_matrix}" "\${WORKDIR}/"
    fi

    OPT_ARGS=""

    GENE_SUMMARY_ARGS=""
    for f in \${WORKDIR}/*.gene_summary.txt; do
        [ -f "\${f}" ] && GENE_SUMMARY_ARGS="\${GENE_SUMMARY_ARGS} \${f}"
    done
    if [ -n "\${GENE_SUMMARY_ARGS}" ]; then
        OPT_ARGS="\${OPT_ARGS} --gene-summary \${GENE_SUMMARY_ARGS}"
    fi

    SGRNA_SUMMARY_ARGS=""
    for f in \${WORKDIR}/*.sgrna_summary.txt; do
        [ -f "\${f}" ] && SGRNA_SUMMARY_ARGS="\${SGRNA_SUMMARY_ARGS} \${f}"
    done
    if [ -n "\${SGRNA_SUMMARY_ARGS}" ]; then
        OPT_ARGS="\${OPT_ARGS} --sgrna-summary \${SGRNA_SUMMARY_ARGS}"
    fi

    if [ -f "${design_matrix}" ]; then
        OPT_ARGS="\${OPT_ARGS} --design-matrix ${design_matrix}"
    fi

    if [ "${params_obj.skip_enrichment}" = "true" ] || [ "${params_obj.skip_enrichment}" = true ]; then
        OPT_ARGS="\${OPT_ARGS} --skip-enrichment"
    else
        OPT_ARGS="\${OPT_ARGS} --enrichment-top-n ${params_obj.enrichment_top_n}"
        OPT_ARGS="\${OPT_ARGS} --enrichment-fdr ${params_obj.enrichment_fdr}"
    fi

    if [ "${params_obj.organism}" != "human" ]; then
        OPT_ARGS="\${OPT_ARGS} --organism ${params_obj.organism}"
    fi

    OPT_ARGS="\${OPT_ARGS} --fdr-threshold ${params_obj.fdr_threshold}"
    OPT_ARGS="\${OPT_ARGS} --top-n ${params_obj.top_n}"

    COUNT_TABLE_IN_WORK=\$(ls \${WORKDIR}/*.count.txt 2>/dev/null | head -1)

    echo "[KGE_REPORT] Running: mageck report -n ${prefix} -k \${COUNT_TABLE_IN_WORK} \${OPT_ARGS}"

    cd "\${WORKDIR}"
    mageck report \\
        -n "${prefix}" \\
        -k "\${COUNT_TABLE_IN_WORK}" \\
        \${OPT_ARGS}
    cd ..

    cp "\${WORKDIR}/${prefix}.report.html" . 2>/dev/null || true

    mkdir -p "${prefix}_report_data"
    cp "\${WORKDIR}/"*.gene_summary.txt "${prefix}_report_data/" 2>/dev/null || true
    cp "\${WORKDIR}/"*.sgrna_summary.txt "${prefix}_report_data/" 2>/dev/null || true
    cp "\${WORKDIR}/"*.log "${prefix}_report_data/" 2>/dev/null || true
    cp "\${WORKDIR}/"*.count.txt "${prefix}_report_data/" 2>/dev/null || true

    echo "[KGE_REPORT] Done."
    ls -la ${prefix}.report.html 2>/dev/null || echo "Warning: HTML report not found"
    """
}
