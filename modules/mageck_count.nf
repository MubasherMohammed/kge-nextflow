/*
 * MAGeCK COUNT module — sgRNA counting from FASTQ files
 *
 * Counts sgRNA reads from FASTQ files using the provided library.
 * Supports both single-end and paired-end reads.
 * Emits count table, normalized counts, summary, and log.
 */

process MAGECK_COUNT {
    tag "${prefix}"
    label 'mageck_count'

    input:
        path library_file
        path fastqs
        val sample_labels
        val params_obj

    output:
        path "${prefix}.count.txt",            emit: count_table
        path "${prefix}.count_normalized.txt",  emit: count_normalized
        path "${prefix}.countsummary.txt",      emit: count_summary
        path "${prefix}.log",                   emit: log

    script:
    prefix = params_obj.output_prefix ?: 'mageck'
    """
    #! /usr/bin/env bash
    echo "[MAGECK_COUNT] Starting sgRNA counting..."
    echo "[MAGECK_COUNT] Library: ${library_file}"
    echo "[MAGECK_COUNT] Sample labels: ${sample_labels}"

    # Build the fastq argument — collect all FASTQ files
    FASTQ_ARG=""
    for fq in ${fastqs}; do
        FASTQ_ARG="\${FASTQ_ARG} \${fq}"
    done

    # Build optional arguments
    OPT_ARGS=""

    if [ -n "${params_obj.sample_labels}" ]; then
        OPT_ARGS="\${OPT_ARGS} --sample-label ${params_obj.sample_labels}"
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

    if [ "${params_obj.trim5}" != "AUTO" ]; then
        OPT_ARGS="\${OPT_ARGS} --trim-5 ${params_obj.trim5}"
    fi

    if [ "${params_obj.sgrna_len}" != "20" ]; then
        OPT_ARGS="\${OPT_ARGS} --sgrna-len ${params_obj.sgrna_len}"
    fi

    if [ "${params_obj.count_n}" = "true" ] || [ "${params_obj.count_n}" = true ]; then
        OPT_ARGS="\${OPT_ARGS} --count-n"
    fi

    if [ "${params_obj.reverse_complement}" = "true" ] || [ "${params_obj.reverse_complement}" = true ]; then
        OPT_ARGS="\${OPT_ARGS} --reverse-complement"
    fi

    if [ "${params_obj.html_report}" = "true" ] || [ "${params_obj.html_report}" = true ]; then
        OPT_ARGS="\${OPT_ARGS} --html-report"
    fi

    echo "[MAGECK_COUNT] Running: mageck count -l ${library_file} -n ${prefix} \${OPT_ARGS} --fastq \${FASTQ_ARG}"

    mageck count \\
        -l "${library_file}" \\
        -n "${prefix}" \\
        \${OPT_ARGS} \\
        --fastq \${FASTQ_ARG}

    echo "[MAGECK_COUNT] Counting complete."
    """
}