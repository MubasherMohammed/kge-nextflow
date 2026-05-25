/*
 * KGE REPORT module — Interactive Plotly HTML Report Generation
 *
 * Runs `mageck report` using the KGE-enhanced MAGeCK with interactive
 * Plotly charts, dynamic gene tables, pathway enrichment, and
 * FLUTE-style gene classification.
 *
 * Inputs:
 *   - count_table:       the read count table
 *   - gene_summaries:    one or more *.gene_summary.txt files (from RRA and/or MLE)
 *   - sgrna_summaries:   one or more *.sgrna_summary.txt files (from RRA and/or MLE)
 *   - design_matrix:     design matrix file (or NO_DESIGN_MATRIX marker if not provided)
 *   - params_obj:        pipeline parameters
 *
 * The script detects NO_DESIGN_MATRIX and skips MLE-specific args.
 * All input files are staged by Nextflow in the work directory, so
 * no subdirectory or cd is needed.
 */

process KGE_REPORT {
    publishDir "${params.output_dir}/kge_report", mode: 'copy'
    tag "${prefix}"
    label 'kge_report'

    input:
        path count_table
        path gene_summaries
        path sgrna_summaries
        path design_matrix
        val params_obj

    output:
        path "${prefix}.report.html", emit: html_report
        path "${prefix}_report_data/", emit: report_data

    script:
    prefix = params_obj.output_prefix ?: 'mageck'
    /*
     * Mageck report sub-command gathers gene/sgrna summaries and the
     * count table already staged in the work directory.  No cd, no
     * subdirectory — files are referenced by name directly.
     */
    """
    #! /usr/bin/env bash
    echo "[KGE_REPORT] Generating interactive HTML report..."

    # ---- Build optional arguments ----

    OPT_ARGS=""

    # Gene summaries — glob for any *.gene_summary.txt in work dir
    GENE_SUMMARY_ARGS=""
    for f in *.gene_summary.txt; do
        [ -f "\${f}" ] && GENE_SUMMARY_ARGS="\${GENE_SUMMARY_ARGS} \${f}"
    done
    if [ -n "\${GENE_SUMMARY_ARGS}" ]; then
        OPT_ARGS="\${OPT_ARGS} --gene-summary \${GENE_SUMMARY_ARGS}"
    fi

    # sgRNA summaries — glob for any *.sgrna_summary.txt in work dir
    SGRNA_SUMMARY_ARGS=""
    for f in *.sgrna_summary.txt; do
        [ -f "\${f}" ] && SGRNA_SUMMARY_ARGS="\${SGRNA_SUMMARY_ARGS} \${f}"
    done
    if [ -n "\${SGRNA_SUMMARY_ARGS}" ]; then
        OPT_ARGS="\${OPT_ARGS} --sgrna-summary \${SGRNA_SUMMARY_ARGS}"
    fi

    # Design matrix — skip if marker file (RRA-only mode)
    if [ "$(basename ${design_matrix})" != "NO_DESIGN_MATRIX" ]; then
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

    # FDR threshold and top-n
    OPT_ARGS="\${OPT_ARGS} --fdr-threshold ${params_obj.fdr_threshold}"
    OPT_ARGS="\${OPT_ARGS} --top-n ${params_obj.top_n}"

    echo "[KGE_REPORT] Running: mageck report -n ${prefix} -k ${count_table} \${OPT_ARGS}"

    mageck report \\
        -n "${prefix}" \\
        -k "${count_table}" \\
        \${OPT_ARGS}

    # Collect report data
    mkdir -p "${prefix}_report_data"
    cp *.gene_summary.txt "${prefix}_report_data/" 2>/dev/null || true
    cp *.sgrna_summary.txt "${prefix}_report_data/" 2>/dev/null || true
    cp *.log "${prefix}_report_data/" 2>/dev/null || true
    cp *.count.txt "${prefix}_report_data/" 2>/dev/null || true

    echo "[KGE_REPORT] Done."
    ls -la ${prefix}.report.html 2>/dev/null || echo "Warning: HTML report not found"
    """
}