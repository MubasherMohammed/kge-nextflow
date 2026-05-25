# kge — CRISPR KO Screen Analysis Pipeline

Nextflow pipeline for end-to-end CRISPR-Cas9 knockout screen analysis: **flowcell demultiplexing → MAGeCK count/test/MLE → interactive KGE HTML report**.

The pipeline auto-detects what to run based on the files you provide:

| Files provided | What runs |
|---|---|
| `--count_table` + `--comparisons` | RRA only |
| `--count_table` + `--design_matrix` | MLE only |
| `--count_table` + `--comparisons` + `--design_matrix` | Both RRA + MLE |

## Quick Start

### Install

```bash
curl -fsSL https://get.nextflow.io | bash
git clone https://github.com/MubasherMohammed/kge-nextflow.git
cd kge-nextflow
bash install.sh
conda activate mageckenv
```

### Run

**RRA + MLE (most common):**

```bash
nextflow run kge -profile conda \
  --count_table all_samples.count.txt \
  --comparisons comparisons.txt \
  --design_matrix design_matrix.txt
```

**RRA only:**

```bash
nextflow run kge -profile conda \
  --count_table all_samples.count.txt \
  --comparisons comparisons.txt
```

**MLE only:**

```bash
nextflow run kge -profile conda \
  --count_table all_samples.count.txt \
  --design_matrix design_matrix.txt
```

**From FASTQ (with counting):**

```bash
nextflow run kge -profile conda \
  --library_file library.txt \
  --fastq_dir ./fastq \
  --comparisons comparisons.txt
```

**From BCL (full pipeline):**

```bash
nextflow run kge -profile conda \
  --demultiplex \
  --run_folder /data/illumina_run \
  --sample_sheet SampleSheet.csv \
  --library_file library.txt \
  --comparisons comparisons.txt
```

**Using a parameters file:**

```bash
cp assets/params_template.yml my-params.yml
nextflow run kge -profile conda -params-file my-params.yml
```

## Comparisons File

Create a TSV file with all RRA comparisons. Each row produces a separate MAGeCK test run in parallel:

```tsv
treatment	control
ETP	Control_6d
ETP	Control_12d
Mid_6d	Control_6d
High_6d	Control_6d
Low_12d	Control_12d
Mid_12d	Control_12d
High_12d	Control_12d
```

See `assets/comparisons_template.txt`.

## Design Matrix (MLE)

Tab-separated. Column 1 = sample names (must match count table header). Remaining columns = condition indicators (0/1):

```
Sample	baseline	Day6_Control	Day6_Mid	Day6_High	Day12_Control	Day12_Low	Day12_Mid	Day12_High
ETP	1	0	0	0	0	0	0	0
Control_6d	1	1	0	0	0	0	0	0
Mid_6d	1	1	1	0	0	0	0	0
High_6d	1	1	0	1	0	0	0	0
Control_12d	1	0	0	0	1	0	0	0
Low_12d	1	0	0	0	1	1	0	0
Mid_12d	1	0	0	0	1	0	1	0
High_12d	1	0	0	0	1	0	0	1
```

See `assets/design_matrix_template.txt` for more examples.

## Profiles

| Profile | Executor | Container | Use Case |
|---------|----------|-----------|----------|
| `conda` | local | conda | Local workstation |
| `docker` | local | Docker | Local with Docker |
| `singularity` | local | Singularity | HPC cluster |
| `slurm` | SLURM | — | SLURM cluster (combine with conda/singularity) |
| `dardel` | local | conda | PDC/KTH Dardel |

```bash
nextflow run kge -profile conda ...
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

## Output Structure

```
results/
├── mageck_test/          # RRA results (one per comparison)
│   ├── ETP_vs_Control_6d.gene_summary.txt
│   ├── ETP_vs_Control_6d.sgrna_summary.txt
│   ├── Mid_6d_vs_Control_6d.gene_summary.txt
│   └── ...
├── mageck_mle/           # MLE results (if --design_matrix provided)
│   ├── *.gene_summary.txt
│   └── *.sgrna_summary.txt
├── kge_report/           # Interactive HTML report
│   ├── mageck.report.html
│   └── mageck_report_data/
└── multiqc/              # Aggregated QC report (if FASTQ input)
    └── multiqc_report.html
```

## Key Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--count_table` | `''` | Pre-computed count table (skips demux + count) |
| `--comparisons` | `''` | TSV file with treatment/control pairs → triggers RRA |
| `--design_matrix` | `''` | Design matrix file → triggers MLE |
| `--fastq_dir` | `''` | Directory with FASTQ files |
| `--demultiplex` | `false` | Enable BCL → FASTQ |
| `--library_file` | `''` | sgRNA library file (required for FASTQ mode) |
| `--html_report` | `true` | Generate interactive HTML report |
| `--organism` | `human` | `human` or `mouse` |
| `--norm_method` | `median` | `none`, `median`, `total`, `control` |
| `--output_dir` | `./results` | Output directory |

Full parameter reference: `assets/params_template.yml`

## Credits

- **MAGeCK** — Wei Li, Han Xu, Xiaole Liu lab (BSD License)
- **KGE enhancements** — Interactive Plotly reports, pathway enrichment, FLUTE-style classification
- **Pipeline framework** — Nextflow

