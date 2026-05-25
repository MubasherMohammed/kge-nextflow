/*
 * MAGeCK MLE module — Maximum Likelihood Estimation analysis
 *
 * Performs MLE analysis for multi-condition CRISPR screens,
 * supporting gene essentiality estimation across treatment conditions.
 */

process MAGECK_MLE_ANALYSIS {
    tag "${prefix}"
    label 'mageck_mle'

    input:
        path count_table
        path design_matrix
        val params_obj

    output:
        path "*.gene_summary.txt",  emit: gene_summary
        path "*.sgrna_summary.txt", emit: sgrna_summary

    script:
    prefix = params_obj.output_prefix ?: 'mageck_mle'
    """
    #! /usr/bin/env bash
    echo "[MAGECK_MLE] Starting MLE analysis..."
    echo "[MAGECK_MLE] Count table: ${count_table}"
    echo "[MAGECK_MLE] Design matrix: ${design_matrix}"

    # Build optional arguments
    OPT_ARGS=""

    if [ "${params_obj.norm_method}" != "median" ]; then
        OPT_ARGS="\${OPT_ARGS} --norm-method ${params_obj.norm_method}"
    fi

    if [ -n "${params_obj.control_sgrna}" ] && [ "${params_obj.control_sgrna}" != "false" ]; then
        OPT_ARGS="\${OPT_ARGS} --control-sgrna ${params_obj.control_sgrna}"
    fi

    if [ -n "${params_obj.control_gene}" ] && [ "${params_obj.control_gene}" != "false" ]; then
        OPT_ARGS="\${OPT_ARGS} --control-gene ${params_obj.control_gene}"
    fi

    if [ -n "${params_obj.beta_labels}" ] && [ "${params_obj.beta_labels}" != "false" ]; then
        OPT_ARGS="\${OPT_ARGS} --beta-labels ${params_obj.beta_labels}"
    fi

    if [ -n "${params_obj.include_samples}" ] && [ "${params_obj.include_samples}" != "false" ]; then
        OPT_ARGS="\${OPT_ARGS} --include-samples ${params_obj.include_samples}"
    fi

    if [ "${params_obj.threads}" -gt 1 ]; then
        OPT_ARGS="\${OPT_ARGS} --threads ${params_obj.threads}"
    fi

    if [ "${params_obj.permutation_round}" != "2" ]; then
        OPT_ARGS="\${OPT_ARGS} --permutation-round ${params_obj.permutation_round}"
    fi

    if [ "${params_obj.html_report}" = "true" ] || [ "${params_obj.html_report}" = true ]; then
        OPT_ARGS="\${OPT_ARGS} --html-report"
    fi

    echo "[MAGECK_MLE] Running: mageck mle -k ${count_table} -d ${design_matrix} \${OPT_ARGS} -n ${prefix}"

    mageck mle \\
        -k "${count_table}" \\
        -d "${design_matrix}" \\
        \${OPT_ARGS} \\
        -n "${prefix}"

    echo "[MAGECK_MLE] MLE analysis complete."
    """
}