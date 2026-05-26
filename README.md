# kge — CRISPR KO Screen Analysis Pipeline

Nextflow pipeline for end-to-end CRISPR-Cas9 knockout screen analysis: **flowcell demultiplexing → MAGeCK count/test/MLE → interactive KGE HTML report**.

The pipeline auto-detects what to run based on the files you provide:

| Files provided | What runs |
|---|---|
| `--count_table` + `--comparisons` | RRA only |
| `--count_table` + `--design_matrix` | MLE only |
| `--count_table` + `--comparisons` + `--design_matrix` | Both RRA + MLE |

## Quick Start

There are two ways to get started: **Docker** (recommended — no conda setup needed) or **conda** (for local development without Docker).

### Option A: Docker (Recommended)

**Prerequisites:** [Docker Desktop](https://docs.docker.com/get-docker/) and [Nextflow](https://www.nextflow.io/docs/latest/getstarted.html).

```bash
# Pull the pre-built image
docker pull mobasherbarsi/mageck-kge:0.5.9.5

# Clone the pipeline
git clone https://github.com/MubasherMohammed/kge-nextflow.git
cd kge-nextflow

# Run with Docker profile
nextflow run main.nf -profile docker \
  --count_table all_samples.count.txt \
  --comparisons comparisons.txt
```

> The Docker image includes MAGeCK 0.5.9.5 with KGE interactive Plotly HTML reports, pathway enrichment, and FLUTE-style gene classification pre-installed.

#### Building the Docker Image from Source

To build the Docker image locally instead of pulling from Docker Hub:

```bash
docker build -t mobasherbarsi/mageck-kge:0.5.9.5 .
```

This builds from `Dockerfile` at the project root using the conda environment defined in `environment.yml`, then overlays the KGE `.py` modifications from the `mageck/` directory.

### Option B: Conda (Local Development)

**Prerequisites:** [conda](https://docs.conda.io/projects/conda/en/latest/user-guide/install/) and [Nextflow](https://www.nextflow.io/docs/latest/getstarted.html).

```bash
git clone https://github.com/MubasherMohammed/kge-nextflow.git
cd kge-nextflow
bash install.sh          # Creates 'mageckenv' conda environment
conda activate mageckenv
```

> The `install.sh` script handles all platform detection (including Apple Silicon Rosetta 2 emulation) and overlays the KGE modifications onto the installed MAGeCK package.

### Run

**RRA + MLE (most common):**

```bash
# With Docker
nextflow run main.nf -profile docker \
  --count_table all_samples.count.txt \
  --comparisons comparisons.txt \
  --design_matrix design_matrix.txt

# With conda
nextflow run main.nf -profile conda \
  --count_table all_samples.count.txt \
  --comparisons comparisons.txt \
  --design_matrix design_matrix.txt
```

**RRA only (fast — 7 comparisons processed in ~10 min):**

```bash
nextflow run main.nf -profile docker \
  --count_table all_samples.count.txt \
  --comparisons comparisons.txt
```

**MLE only (computationally heavy — 19K genes × 8 conditions takes 60–90 min):**

```bash
nextflow run main.nf -profile docker \
  --count_table all_samples.count.txt \
  --design_matrix design_matrix.txt
```

**From FASTQ (with counting):**

```bash
nextflow run main.nf -profile docker \
  --library_file library.txt \
  --fastq_dir ./fastq \
  --comparisons comparisons.txt
```

**From BCL (full pipeline):**

```bash
nextflow run main.nf -profile docker \
  --demultiplex \
  --run_folder /data/illumina_run \
  --sample_sheet SampleSheet.csv \
  --library_file library.txt \
  --comparisons comparisons.txt
```

**Using a parameters file:**

```bash
cp assets/params_template.yml my-params.yml
nextflow run main.nf -profile docker -params-file my-params.yml
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
| `conda` | local | conda environment | Local workstation |
| `docker` | local | Docker container | Local with Docker (recommended) |
| `singularity` | local | Singularity SIF | HPC cluster |
| `slurm` | SLURM | — | SLURM cluster (combine with conda/singularity) |
| `dardel` | local | conda | PDC/KTH Dardel HPC |

```bash
# Conda (local development)
nextflow run main.nf -profile conda ...

# Docker (recommended for reproducibility)
nextflow run main.nf -profile docker ...

# Singularity on HPC (SLURM batch)
nextflow run main.nf -profile singularity,slurm ...

# Dardel (PDC/KTH)
nextflow run main.nf -profile dardel ...
```

### Docker

The `docker` profile uses `mobasherbarsi/mageck-kge:0.5.9.5` from Docker Hub. This image contains:
- MAGeCK 0.5.9.5 with KGE interactive HTML report extensions
- Conda environment with all dependencies (Python, R, Plotly, decoupler)
- KGE custom `.py` overlays from the `mageck/` directory

**Pull pre-built:**
```bash
docker pull mobasherbarsi/mageck-kge:0.5.9.5
```

**Build locally:**
```bash
docker build -t mobasherbarsi/mageck-kge:0.5.9.5 .
```

The Dockerfile:
1. Starts from `continuumio/miniconda3:23.10`
2. Creates the conda environment from `environment.yml`
3. Overlays KGE modifications from `mageck/*.py` onto the installed MAGeCK package
4. Sets `CMD ["mageck", "--help"]` (no `ENTRYPOINT` — Nextflow's `docker run` uses `bash -c`, so an ENTRYPOINT would wrap all commands and break execution)

### Singularity

The `singularity` profile uses the `Singularity` definition file at the project root. This file boots from the same Docker image (`mobasherbarsi/mageck-kge:0.5.9.5`) so the software stack is identical.

**Build a SIF file (requires Singularity installed on Linux):**

```bash
singularity build mageck-kge.sif Singularity
```

**Or pull directly from Docker Hub (no definition file needed):**

```bash
singularity pull docker://mobasherbarsi/mageck-kge:0.5.9.5
```

**Run with Nextflow:**

```bash
nextflow run main.nf -profile singularity \
  --count_table all_samples.count.txt \
  --comparisons comparisons.txt
```

> **Note:** The Singularity definition has **no `%runscript`**. Nextflow uses `singularity exec` (not `singularity run`), which bypasses the runscript. A runscript would interfere with process execution in the same way as a Docker `ENTRYPOINT`.

### Dardel (PDC/KTH HPC)

For the Dardel HPC cluster at PDC/KTH:

```bash
# Install (one-time setup)
bash install_dardel.sh

# Run
nextflow run main.nf -profile dardel \
  --count_table all_samples.count.txt \
  --comparisons comparisons.txt
```

The Dardel profile uses `slurm` as the executor and loads PDC/miniconda3 modules before running processes.

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
├── kge_report/           # Interactive Plotly HTML report (27 MB for 7 comparisons)
│   └── mageck.report.html
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

