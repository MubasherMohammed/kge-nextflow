/*
 * ==========================================================================
 * kge — CRISPR KO Screen Analysis Pipeline
 * ==========================================================================
 *
 * Driven by the files you provide:
 *   --count_table    → required, always the starting point
 *   --comparisons    → triggers RRA (one run per treatment/control pair)
 *   --design_matrix  → triggers MLE
 *   --comparisons + --design_matrix → runs both RRA and MLE
 *
 * Usage examples:
 *
 *   # RRA only (7 comparisons):
 *   nextflow run kge -profile conda \
 *     --count_table all_samples.count.txt \
 *     --comparisons comparisons.txt
 *
 *   # Both RRA + MLE:
 *   nextflow run kge -profile conda \
 *     --count_table all_samples.count.txt \
 *     --comparisons comparisons.txt \
 *     --design_matrix design_matrix.txt
 *
 *   # MLE only:
 *   nextflow run kge -profile conda \
 *     --count_table all_samples.count.txt \
 *     --design_matrix design_matrix.txt
 */

nextflow.enable.dsl = 2

// ============================================================================
// INCLUDES
// ============================================================================

include { DEMULTIPLEX        } from './modules/demultiplex'
include { FASTQC_READS       } from './modules/fastqc'
include { MAGECK_COUNT        } from './modules/mageck_count'
include { MAGECK_TEST_RRA     } from './modules/mageck_test'
include { MAGECK_MLE_ANALYSIS } from './modules/mageck_mle'
include { KGE_REPORT          } from './modules/kge_report'
include { MULTIQC_REPORT      } from './modules/multiqc'

// ============================================================================
// WORKFLOW
// ============================================================================

workflow {

    // ------------------------------------------------------------------
    // Validate required inputs
    // ------------------------------------------------------------------
    validate_inputs()

    // ==================================================================
    // INPUT STAGE: resolve count table from one of three sources
    // ==================================================================

    if (params.count_table) {
        // Mode A: start from existing count table — skip demux + count
        count_table_ch    = Channel.fromPath(params.count_table, checkIfExists: true)
        count_norm_ch     = Channel.empty()
        count_summary_ch  = Channel.empty()
    } else if (params.demultiplex) {
        // Mode B: start from BCL — demux → fastqc → count
        demux_result = DEMULTIPLEX(
            file(params.run_folder, checkIfExists: true),
            file(params.sample_sheet, checkIfExists: true)
        )

        fastq_ch = demux_result.out.fastqs
            .flatMap { dir -> dir.listFiles().collect { it } }
            .filter { it.getName() =~ /.*\.(fastq\.gz|fastq|fq\.gz|fq)$/ }

        if (params.fastqc) {
            FASTQC_READS(fastq_ch.map { it })
        }

        MAGECK_COUNT(
            file(params.library_file, checkIfExists: true),
            fastq_ch.collect(),
            params.sample_labels,
            params
        )
        count_table_ch    = MAGECK_COUNT.out.count_table
        count_norm_ch     = MAGECK_COUNT.out.count_normalized
        count_summary_ch  = MAGECK_COUNT.out.count_summary

    } else if (params.fastq_dir) {
        // Mode C: start from FASTQ files
        fastq_ch = Channel.fromPath(
            "${params.fastq_dir}/${params.fastq_pattern}",
            checkIfExists: true
        )

        if (params.fastqc) {
            FASTQC_READS(fastq_ch.map { it })
        }

        MAGECK_COUNT(
            file(params.library_file, checkIfExists: true),
            Channel.fromPath("${params.fastq_dir}/${params.fastq_pattern}", checkIfExists: true)
                .collect(),
            params.sample_labels,
            params
        )
        count_table_ch    = MAGECK_COUNT.out.count_table
        count_norm_ch     = MAGECK_COUNT.out.count_normalized
        count_summary_ch  = MAGECK_COUNT.out.count_summary

    } else {
        log.error "ERROR: provide one of --count_table, --fastq_dir, or --demultiplex"
        System.exit(1)
    }

    // ==================================================================
    // RRA: iterate over comparison pairs from --comparisons file
    // ==================================================================

    rra_gene_summaries  = Channel.empty().collect()
    rra_sgrna_summaries = Channel.empty().collect()

    if (params.comparisons) {
        // Parse the comparisons TSV: one (treatment, control) pair per row
        comparisons_ch = Channel.fromPath(params.comparisons, checkIfExists: true)
            .splitCsv(header: true, sep: '\t')
            .map { row -> tuple(row['treatment'].trim(), row['control'].trim()) }

        // Combine: (count_table) × (treatment, control) → one MAGECK_TEST_RRA per pair
        MAGECK_TEST_RRA(
            count_table_ch.combine(comparisons_ch),
            params
        )

        rra_gene_summaries  = MAGECK_TEST_RRA.out.gene_summary.collect()
        rra_sgrna_summaries = MAGECK_TEST_RRA.out.sgrna_summary.collect()
    }

    // ==================================================================
    // MLE: requires --design_matrix
    // ==================================================================

    mle_gene_summaries  = Channel.empty().collect()
    mle_sgrna_summaries = Channel.empty().collect()
    design_matrix_ch     = Channel.empty().collect()

    if (params.design_matrix) {
        MAGECK_MLE_ANALYSIS(
            count_table_ch,
            file(params.design_matrix, checkIfExists: true),
            params
        )
        mle_gene_summaries  = MAGECK_MLE_ANALYSIS.out.gene_summary.collect()
        mle_sgrna_summaries = MAGECK_MLE_ANALYSIS.out.sgrna_summary.collect()
        design_matrix_ch     = Channel.fromPath(params.design_matrix).collect()
    }

    // ==================================================================
    // KGE Interactive HTML Report
    // ==================================================================

    if (params.html_report) {
        KGE_REPORT(
            count_table_ch,
            rra_gene_summaries,
            rra_sgrna_summaries,
            mle_gene_summaries,
            mle_sgrna_summaries,
            design_matrix_ch,
            params
        )
    }
}


// ============================================================================
// INPUT VALIDATION
// ============================================================================

def validate_inputs() {
    def inputModes = [params.count_table ? 1 : 0, params.fastq_dir ? 1 : 0, params.demultiplex ? 1 : 0].sum()
    if (inputModes == 0) {
        log.error "ERROR: provide one of --count_table, --fastq_dir, or --demultiplex"
        System.exit(1)
    }
    if (inputModes > 1) {
        log.error "ERROR: provide only one input mode: --count_table, --fastq_dir, or --demultiplex"
        System.exit(1)
    }

    if (params.demultiplex) {
        if (!params.run_folder)    { log.error "ERROR: --run_folder is required with --demultiplex"; System.exit(1) }
        if (!params.sample_sheet)  { log.error "ERROR: --sample_sheet is required with --demultiplex"; System.exit(1) }
        if (!params.library_file)  { log.error "ERROR: --library_file is required when starting from FASTQ"; System.exit(1) }
    }

    if (params.fastq_dir && !params.library_file) {
        log.error "ERROR: --library_file is required when starting from FASTQ"
        System.exit(1)
    }

    if (!params.comparisons && !params.design_matrix) {
        log.error "ERROR: provide at least one of --comparisons (for RRA) or --design_matrix (for MLE)"
        System.exit(1)
    }

    if (params.design_matrix && !params.comparisons) {
        log.info "  [kge] MLE-only mode (--design_matrix provided, no --comparisons)"
    }
    if (params.comparisons && !params.design_matrix) {
        log.info "  [kge] RRA-only mode (--comparisons provided, no --design_matrix)"
    }

    def mode = params.count_table ? 'count_table' : (params.demultiplex ? 'BCL' : 'FASTQ')
    def analysis = params.comparisons && params.design_matrix ? 'RRA+MLE' : (params.comparisons ? 'RRA' : 'MLE')

    log.info """
    ============================================
      kge: CRISPR KO Screen Pipeline
    ============================================
      Input mode     : ${mode}
      Analysis       : ${analysis}
      Comparisons    : ${params.comparisons ?: 'N/A (MLE only)'}
      Design matrix  : ${params.design_matrix ?: 'N/A (RRA only)'}
      HTML report    : ${params.html_report}
      Output dir     : ${params.output_dir}
    ============================================
    """.stripIndent()
}