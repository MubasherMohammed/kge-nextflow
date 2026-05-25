/*
 * ==========================================================================
 * KGE-nextflow — CRISPR KO Screen Analysis Pipeline
 * ==========================================================================
 *
 * Pipeline stages:
 *   1. DEMULTIPLEX — BCL → FASTQ (bcl-convert or bcl2fastq)
 *   2. FASTQC      — Pre-alignment quality control
 *   3. MAGECK_COUNT — sgRNA counting from FASTQ
 *   4. MAGECK_TEST  — RRA statistical test
 *   5. MAGECK_MLE   — MLE analysis (optional)
 *   6. KGE_REPORT   — Interactive HTML report generation
 *   7. MULTIQC      — Aggregate QC report
 *
 * Usage:
 *   # Start from FASTQ (most common):
 *   nextflow run kge -profile conda \
 *     --library_file library.txt \
 *     --fastq_dir ./fastq \
 *     --sample_labels "Treat,Control" \
 *     --treatment_ids "Treat" \
 *     --control_ids "Control"
 *
 *   # Start from BCL (full pipeline):
 *   nextflow run kge -profile conda \
 *     --demultiplex \
 *     --run_folder /data/run_folder \
 *     --sample_sheet SampleSheet.csv \
 *     --library_file library.txt \
 *     --treatment_ids "Treat" \
 *     --control_ids "Control"
 */

nextflow.enable.dsl = 2

// ============================================================================
// INCLUDES
// ============================================================================

include { DEMULTIPLEX      } from './modules/demultiplex'
include { FASTQC_READS      } from './modules/fastqc'
include { MAGECK_COUNT      } from './modules/mageck_count'
include { MAGECK_TEST_RRA   } from './modules/mageck_test'
include { MAGECK_MLE_ANALYSIS } from './modules/mageck_mle'
include { KGE_REPORT        } from './modules/kge_report'
include { MULTIQC_REPORT    } from './modules/multiqc'

// ============================================================================
// WORKFLOW
// ============================================================================

workflow {

    // ------------------------------------------------------------------
    // Validate required inputs
    // ------------------------------------------------------------------
    validate_inputs()

    // ------------------------------------------------------------------
    // Stage 1: Demultiplex (optional — start from BCL)
    // ------------------------------------------------------------------
    demux_fastqs = Channel.empty()
    if (params.demultiplex) {
        demux_fastqs = DEMULTIPLEX(
            file(params.run_folder, checkIfExists: true),
            file(params.sample_sheet, checkIfExists: true)
        )
        demux_fastqs = demux_fastqs.map { it[0] }
            .flatMap { dir -> dir.listFiles().collect { it } }
            .filter { it.getName() =~ /.*\.(fastq\.gz|fastq|fq\.gz|fq)$/ }
            .map { it }
    }

    // ------------------------------------------------------------------
    // Stage 2: Collect FASTQ inputs
    // ------------------------------------------------------------------
    if (params.demultiplex) {
        fastq_ch = demux_fastqs
    } else if (params.fastq_dir) {
        fastq_ch = Channel.fromPath("${params.fastq_dir}/${params.fastq_pattern}", checkIfExists: true)
    } else {
        fastq_ch = Channel.empty()
    }

    // Group FASTQs by sample name (extract from filename)
    // Expected patterns: SampleName_R1_001.fastq.gz, SampleName_S1_L001_R1_001.fastq.gz
    fastq_by_sample = fastq_ch
        .map { f ->
            def name = f.getName()
                       .replaceAll(/_S\d+_L\d{3}_R[12]_001\.fastq\.gz$/, '')
                       .replaceAll(/_S\d+_L\d{3}_R[12]_001\.fastq$/, '')
                       .replaceAll(/_R[12](?:_\d+)?\.fastq\.gz$/, '')
                       .replaceAll(/_R[12](?:_\d+)?\.fastq$/, '')
            tuple(name, f)
        }
        .groupTuple()

    // ------------------------------------------------------------------
    // Stage 3: FastQC (optional QC)
    // ------------------------------------------------------------------
    fastqc_results = Channel.empty()
    if (params.fastqc) {
        FASTQC_READS(fastq_ch)
        fastqc_results = FASTQC_READS.out.zips.collect()
    }

    // ------------------------------------------------------------------
    // Stage 4: MAGeCK count
    // ------------------------------------------------------------------
    MAGECK_COUNT(
        file(params.library_file, checkIfExists: true),
        Channel.fromPath('${params.fastq_dir}/${params.fastq_pattern}', checkIfExists: true)
            .collect(),
        params.sample_labels,
        params
    )

    count_table = MAGECK_COUNT.out.count_table
    count_normalized = MAGECK_COUNT.out.count_normalized
    count_summary = MAGECK_COUNT.out.count_summary

    // ------------------------------------------------------------------
    // Stage 5: MAGeCK test (RRA)
    // ------------------------------------------------------------------
    if (params.analyze_mode == 'rra' || params.analyze_mode == 'both') {
        MAGECK_TEST_RRA(
            count_table,
            params.treatment_ids,
            params.control_ids,
            params
        )
    }

    rra_gene_summary  = params.analyze_mode in ['rra', 'both']
                        ? MAGECK_TEST_RRA.out.gene_summary
                        : Channel.empty()
    rra_sgrna_summary = params.analyze_mode in ['rra', 'both']
                        ? MAGECK_TEST_RRA.out.sgrna_summary
                        : Channel.empty()

    // ------------------------------------------------------------------
    // Stage 6: MAGeCK MLE (optional)
    // ------------------------------------------------------------------
    mle_gene_summary  = Channel.empty()
    mle_sgrna_summary = Channel.empty()
    if (params.analyze_mode == 'mle' || params.analyze_mode == 'both') {
        MAGECK_MLE_ANALYSIS(
            count_table,
            file(params.design_matrix, checkIfExists: true),
            params
        )
        mle_gene_summary  = MAGECK_MLE_ANALYSIS.out.gene_summary
        mle_sgrna_summary = MAGECK_MLE_ANALYSIS.out.sgrna_summary
    }

    // ------------------------------------------------------------------
    // Stage 7: KGE Interactive HTML Report
    // ------------------------------------------------------------------
    if (params.html_report) {
        KGE_REPORT(
            count_table,
            count_normalized,
            count_summary,
            rra_gene_summary.collect().map { it },
            rra_sgrna_summary.collect().map { it },
            mle_gene_summary.collect().map { it },
            mle_sgrna_summary.collect().map { it },
            Channel.fromPath(params.design_matrix).collect().map { it },
            params
        )
    }

    // ------------------------------------------------------------------
    // Stage 8: MultiQC (aggregate all QC)
    // ------------------------------------------------------------------
    if (params.multiqc) {
        MULTIQC_REPORT(
            Channel.empty()
                .mix(fastqc_results ?: Channel.empty())
                .mix(MAGECK_COUNT.out.log ?: Channel.empty())
                .collect()
        )
    }
}


// ============================================================================
// INPUT VALIDATION
// ============================================================================

def validate_inputs() {
    // Library file is always required
    if (!params.library_file) {
        log.error "ERROR: --library_file is required"
        System.exit(1)
    }

    // At least one input source
    if (!params.demultiplex && !params.fastq_dir) {
        log.error "ERROR: Provide either --demultiplex (with --run_folder and --sample_sheet) or --fastq_dir"
        System.exit(1)
    }

    if (params.demultiplex) {
        if (!params.run_folder) {
            log.error "ERROR: --run_folder is required with --demultiplex"
            System.exit(1)
        }
        if (!params.sample_sheet) {
            log.error "ERROR: --sample_sheet is required with --demultiplex"
            System.exit(1)
        }
    }

    // Analysis mode
    if (!(params.analyze_mode in ['rra', 'mle', 'both'])) {
        log.error "ERROR: --analyze_mode must be 'rra', 'mle', or 'both'"
        System.exit(1)
    }

    // MLE requires design matrix
    if (params.analyze_mode in ['mle', 'both']) {
        if (!params.design_matrix) {
            log.error "ERROR: --design_matrix is required for MLE analysis"
            System.exit(1)
        }
    }

    // RRA requires treatment/control IDs
    if (params.analyze_mode in ['rra', 'both']) {
        if (!params.treatment_ids) {
            log.error "ERROR: --treatment_ids is required for RRA analysis"
            System.exit(1)
        }
    }

    log.info """
    ============================================
      KGE-nextflow: CRISPR KO Screen Pipeline
    ============================================
      Demultiplex   : ${params.demultiplex}
      FASTQ source   : ${params.demultiplex ? 'BCL conversion' : params.fastq_dir}
      Library file   : ${params.library_file}
      Analysis mode  : ${params.analyze_mode}
      HTML report    : ${params.html_report}
      Output dir     : ${params.output_dir}
    ============================================
    """.stripIndent()
}