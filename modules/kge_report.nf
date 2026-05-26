/*
 * KGE REPORT module — Interactive Plotly HTML Report Generation
 *
 * Runs `mageck report` using the KGE-enhanced MAGeCK with interactive
 * Plotly charts, dynamic gene tables, pathway enrichment, and
 * FLUTE-style gene classification.
 *
 * All bash-argument decisions are pre-computed in Groovy to avoid
 * Nextflow GString template issues with dollar signs in bash strings.
 */

process KGE_REPORT {
    publishDir "${params.output_dir}/kge_report", mode: 'copy'
    tag "${report_prefix}"
    label 'kge_report'

    input:
        path count_table_file
        path gene_summaries
        path sgrna_summaries
        path design_matrix_file
        val skip_enrichment
        val enrichment_top_n
        val enrichment_fdr
        val organism
        val fdr_threshold
        val top_n_value
        val output_prefix

    output:
        path "${report_prefix}.report.html", emit: html_report

    script:
    report_prefix = output_prefix ?: 'mageck'

    // Pre-compute argument values
    dm_arg = (design_matrix_file.name == 'NO_DESIGN_MATRIX') ? '' : "--design-matrix ${design_matrix_file}"
    enrich_arg = skip_enrichment ? '--skip-enrichment' : "--enrichment-top-n ${enrichment_top_n} --enrichment-fdr ${enrichment_fdr}"
    org_arg = (organism != 'human') ? "--organism ${organism}" : ''

    """
    #! /usr/bin/env bash
    set -euo pipefail

    echo "[KGE_REPORT] Generating interactive HTML report..."

    OPT_ARGS=""

    # Gene summaries — glob staged files
    GENE_ARGS=""
    for f in *.gene_summary.txt; do
        [ -f "\${f}" ] && GENE_ARGS="\${GENE_ARGS} \${f}"
    done
    [ -n "\${GENE_ARGS}" ] && OPT_ARGS="\${OPT_ARGS} --gene-summary \${GENE_ARGS}"

    # sgRNA summaries — glob staged files
    SGRNA_ARGS=""
    for f in *.sgrna_summary.txt; do
        [ -f "\${f}" ] && SGRNA_ARGS="\${SGRNA_ARGS} \${f}"
    done
    [ -n "\${SGRNA_ARGS}" ] && OPT_ARGS="\${OPT_ARGS} --sgrna-summary \${SGRNA_ARGS}"

    # Pre-computed arguments
    OPT_ARGS="\${OPT_ARGS} ${dm_arg}"
    OPT_ARGS="\${OPT_ARGS} ${enrich_arg}"
    OPT_ARGS="\${OPT_ARGS} ${org_arg}"

    # FDR threshold and top-n for plots
    OPT_ARGS="\${OPT_ARGS} --fdr-threshold ${fdr_threshold}"
    OPT_ARGS="\${OPT_ARGS} --top-n ${top_n_value}"

    echo "[KGE_REPORT] Running: mageck report -n ${report_prefix} -k ${count_table_file}"

    mageck report \\
        -n "${report_prefix}" \\
        -k "${count_table_file}" \\
        \${OPT_ARGS}

    echo "[KGE_REPORT] Done."
    ls -la ${report_prefix}.report.html
    """
}
