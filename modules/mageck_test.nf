/*
 * MAGeCK TEST (RRA) module — Robust Rank Aggregation statistical test
 *
 * Runs one RRA comparison per (treatment, control) pair.
 * The workflow uses count_table_ch.combine(comparisons_ch) to broadcast
 * the count table across all comparisons, so this process fires once per
 * row in the comparisons file.
 */

process MAGECK_TEST_RRA {
    publishDir "${params.output_dir}/mageck_test", mode: 'copy'
    tag "${treatment}_vs_${control}"
    label 'mageck_test'

    input:
        tuple path(count_table), val(treatment), val(control)
        val params_obj

    output:
        path "${treatment}_vs_${control}.gene_summary.txt",  emit: gene_summary
        path "${treatment}_vs_${control}.sgrna_summary.txt", emit: sgrna_summary

    script:
    def prefix = "${treatment}_vs_${control}"
    """
    #! /usr/bin/env bash
    echo "[MAGECK_TEST] RRA: ${treatment} vs ${control}"

    OPT_ARGS=""
    if [ -n "${control}" ] && [ "${control}" != "rest" ]; then
        OPT_ARGS="\${OPT_ARGS} -c ${control}"
    fi
    if [ "${params_obj.norm_method}" != "median" ]; then
        OPT_ARGS="\${OPT_ARGS} --norm-method ${params_obj.norm_method}"
    fi
    if [ -n "${params_obj.control_sgrna}" ] && [ "${params_obj.control_sgrna}" != "false" ] && [ "${params_obj.control_sgrna}" != "" ]; then
        OPT_ARGS="\${OPT_ARGS} --control-sgrna ${params_obj.control_sgrna}"
    fi
    if [ -n "${params_obj.control_gene}" ] && [ "${params_obj.control_gene}" != "false" ] && [ "${params_obj.control_gene}" != "" ]; then
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

    mageck test \\
        -k "${count_table}" \\
        -t "${treatment}" \\
        \${OPT_ARGS} \\
        -n "${prefix}"

    echo "[MAGECK_TEST] Done: ${treatment} vs ${control}"
    """
}
