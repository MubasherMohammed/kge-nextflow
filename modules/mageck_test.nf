/*
 * MAGeCK TEST (RRA) module — Robust Rank Aggregation statistical test
 *
 * Performs RRA test on the count table to identify significantly
 * enriched or depleted genes in CRISPR screens.
 */

process MAGECK_TEST_RRA {
    tag "${treatment}_vs_${control}"
    label 'mageck_test'

    input:
        path count_table
        val treatment
        val control
        val params_obj

    output:
        path "*.gene_summary.txt",  emit: gene_summary
        path "*.sgrna_summary.txt", emit: sgrna_summary

    script:
    prefix = params_obj.output_prefix ?: 'mageck'
    """
    #! /usr/bin/env bash
    echo "[MAGECK_TEST] Running RRA test: ${treatment} vs ${control}"

    # Build optional arguments
    OPT_ARGS=""

    if [ -n "${control}" ] && [ "${control}" != "rest" ]; then
        OPT_ARGS="\${OPT_ARGS} -c ${control}"
    fi

    if [ "${params_obj.norm_method}" != "median" ]; then
        OPT_ARGS="\${OPT_ARGS} --norm-method ${params_obj.norm_method}"
    fi

    if [ -n "${params_obj.control_sgrna}" ] && [ "${params_obj.control_sgrna}" != "false" ]; then
        OPT_ARGS="\${OPT_ARGS} --control-sgrna ${params_obj.control_sgrna}"
    fi

    if [ -n "${params_obj.control_gene}" ] && [ "${params_obj.control_gene}" != "false" ]; then
        OPT_ARGS="\${OPT_ARGS} --control-gene ${params_obj.control_gene}"
    fi

    if [ "${params_obj.adjust_method}" != "fdr" ]; then
        OPT_ARGS="\${OPT_ARGS} --adjust-method ${params_obj.adjust_method}"
    fi

    if [ "${params_obj.gene_test_fdr_threshold}" != "0.25" ]; then
        OPT_ARGS="\${OPT_ARGS} --gene-test-fdr-threshold ${params_obj.gene_test_fdr_threshold}"
    fi

    if [ "${params_obj.remove_zero}" != "both" ]; then
        OPT_ARGS="\${OPT_ARGS} --remove-zero ${params_obj.remove_zero}"
    fi

    if [ "${params_obj.gene_lfc_method}" != "median" ]; then
        OPT_ARGS="\${OPT_ARGS} --gene-lfc-method ${params_obj.gene_lfc_method}"
    fi

    if [ "${params_obj.html_report}" = "true" ] || [ "${params_obj.html_report}" = true ]; then
        OPT_ARGS="\${OPT_ARGS} --html-report"
    fi

    echo "[MAGECK_TEST] Running: mageck test -k ${count_table} -t ${treatment} \${OPT_ARGS} -n ${prefix}"

    mageck test \\
        -k "${count_table}" \\
        -t "${treatment}" \\
        \${OPT_ARGS} \\
        -n "${prefix}"

    echo "[MAGECK_TEST] RRA test complete."
    """
}