# kge — CRISPR KO Screen Analysis Pipeline

Nextflow pipeline for end-to-end CRISPR-Cas9 knockout screen analysis: **flowcell demultiplexing → MAGeCK count/test/MLE → interactive KGE HTML report**.

```
BCL/run_folder ──► DEMULTIPLEX ──► FASTQC ──► MAGeCK COUNT ──► MAGeCK TEST (RRA)
                                                        │              │
                                                        └──► MAGeCK MLE ──┘
                                                                              │
                                                              KGE REPORT (HTML) ◄┘
                                                                       │
                                                              MULTIQC ◄──────────┘
```

## Quick Start

### Install

```bash
# 1. Install Nextflow (if not already installed)
curl -fsSL https://get.nextflow.io | bash

# 2. Clone the pipeline
git clone https://github.com/MubasherMohammed/kge-nextflow.git
cd kge-nextflow

# 3. Install KGE-modified MAGeCK (creates conda env 'mageckenv')
bash install.sh
conda activate mageckenv
```

### Run

**From FASTQ — standard screen (most common):**

```bash
nextflow run kge -profile conda \
  --library_file library.txt \
  --fastq_dir ./fastq \
  --sample_labels "Treat_R1,Treat_R2,Ctrl_R1,Ctrl_R2" \
  --treatment_ids "Treat_R1,Treat_R2" \
  --control_ids "Ctrl_R1,Ctrl_R2"
```

**From BCL — full pipeline starting at demultiplexing:**

```bash
nextflow run kge -profile conda \
  --demultiplex \
  --run_folder /data/illumina_run \
  --sample_sheet SampleSheet.csv \
  --library_file library.txt \
  --treatment_ids "Treat" \
  --control_ids "Control"
```

**MLE mode — multi-condition analysis:**

```bash
nextflow run kge -profile conda \
  --library_file library.txt \
  --fastq_dir ./fastq \
  --analyze_mode mle \
  --design_matrix design.txt \
  --sample_labels "ETP_R1,ETP_R2,Ctrl_6d_R1,Ctrl_6d_R2,Drug_6d_R1,Drug_6d_R2"
```

**RRA + MLE combined:**

```bash
nextflow run kge -profile conda \
  --library_file library.txt \
  --fastq_dir ./fastq \
  --analyze_mode both \
  --treatment_ids "Treat" \
  --control_ids "Control" \
  --design_matrix design.txt
```

**Using a parameters file:**

```bash
cp assets/params_template.yml my-params.yml
# edit my-params.yml with your settings
nextflow run kge -profile conda -params-file my-params.yml
```

## Profiles

| Profile | Executor | Container | Use Case |
|---------|----------|-----------|----------|
| `conda` | local | conda | Local workstation |
| `docker` | local | Docker | Local with Docker |
| `singularity` | local | Singularity | HPC cluster |
| `slurm` | SLURM | — | SLURM cluster (combine with conda/singularity) |
| `dardel` | local | conda | PDC/KTH Dardel |

```bash
nextflow run kge -profile docker ...
nextflow run kge -profile singularity,slurm ...
nextflow run kge -profile dardel ...
```

## Pipeline Stages

| Stage | Tool | Description |
|-------|------|-------------|
| DEMULTIPLEX | bcl-convert / bcl2fastq | BCL → FASTQ conversion |
| FASTQC | FastQC | Pre-alignment quality control |
| MAGeCK COUNT | mageck count | sgRNA read counting + normalization |
| MAGeCK TEST | mageck test | RRA statistical test (gene-level) |
| MAGeCK MLE | mageck mle | MLE analysis (multi-condition) |
| KGE REPORT | mageck report | Interactive Plotly HTML report |
| MULTIQC | MultiQC | Aggregate QC report |

## Output Structure

```
results/
├── demultiplex/          # FASTQ files from BCL conversion
├── fastqc/               # FastQC HTML reports
├── mageck_count/         # Count table + normalized counts + QC
│   ├── *.count.txt
│   ├── *.count_normalized.txt
│   └── *.countsummary.txt
├── mageck_test/          # RRA results
│   ├── *.gene_summary.txt
│   └── *.sgrna_summary.txt
├── mageck_mle/           # MLE results (if mode=mle or both)
│   ├── *.gene_summary.txt
│   └── *.sgrna_summary.txt
├── kge_report/           # Interactive HTML report
│   ├── *.report.html
│   └── *_report_data/
└── multiqc/              # Aggregated QC report
    └── multiqc_report.html
```

## Key Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--library_file` | *required* | sgRNA library file |
| `--fastq_dir` | `''` | Directory containing FASTQ files |
| `--demultiplex` | `false` | Enable BCL → FASTQ conversion |
| `--run_folder` | `''` | Illumina run folder (with `--demultiplex`) |
| `--sample_sheet` | `''` | SampleSheet.csv (with `--demultiplex`) |
| `--analyze_mode` | `rra` | `rra`, `mle`, or `both` |
| `--treatment_ids` | `''` | Treatment sample labels (RRA) |
| `--control_ids` | `''` | Control sample labels (RRA) |
| `--day0_label` | `''` | Auto-compare all vs this control |
| `--design_matrix` | `''` | Design matrix file (MLE) |
| `--html_report` | `true` | Generate interactive HTML report |
| `--organism` | `human` | `human` or `mouse` |
| `--norm_method` | `median` | `none`, `median`, `total`, `control` |
| `--skip_enrichment` | `false` | Skip pathway enrichment |
| `--enrichment_top_n` | `50` | Top genes for enrichment |
| `--output_dir` | `./results` | Output directory |

Full parameter reference: `assets/params_template.yml`

## Library File Format

Tab-separated, 3 columns: `sgRNA_ID  sequence  gene_name`

```
sgRNA_001   GGTGCGCGAATCCCTCGATT   AAAS
sgRNA_002   GACCCGTCGTAGCAGCCACT   AAAS
sgRNA_003   GGGCGCGCCATCCGCGCCGA   AAAS
NonTarget_1 AAAAAAAAAAAAAAAAAAAA    NonTargetingControl
```

See `assets/library_template.txt` for detailed instructions.

## Design Matrix Format (MLE)

Tab-separated. Column 1 = sample names (matching count table header). Remaining columns = condition indicators (0/1).

```
Sample    baseline  Drug_6d
ETP_R1       1         0
ETP_R2       1         0
Drug_6d_R1   1         1
Drug_6d_R2   1         1
```

See `assets/design_matrix_template.txt` for more examples.

## Credits

- **MAGeCK** — Wei Li, Han Xu, Xiaole Liu lab (BSD License)
- **KGE enhancements** — Interactive Plotly reports, pathway enrichment, FLUTE-style classification
- **Pipeline framework** — Nextflow

## License

BSD License (same as MAGeCK).