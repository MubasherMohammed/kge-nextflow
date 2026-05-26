# kge — CRISPR KO Screen Analysis Pipeline

Nextflow pipeline for end-to-end CRISPR-Cas9 knockout screen analysis: **flowcell demultiplexing → MAGeCK count/test/MLE → interactive KGE HTML report**.

The pipeline auto-detects what to run based on the files you provide:

| Files provided | What runs |
|---|---|
| `--count_table` + `--comparisons` | RRA only |
| `--count_table` + `--design_matrix` | MLE only |
| `--count_table` + `--comparisons` + `--design_matrix` | Both RRA + MLE |

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Installation](#installation)
  - [Docker (Recommended)](#docker-recommended)
  - [Conda (Local Development)](#conda-local-development)
  - [Singularity (HPC Clusters)](#singularity-hpc-clusters)
- [Input File Formats](#input-file-formats)
  - [Count Table](#count-table)
  - [Comparisons File (RRA)](#comparisons-file-rra)
  - [Design Matrix (MLE)](#design-matrix-mle)
  - [sgRNA Library File](#sgrna-library-file)
- [Usage](#usage)
  - [Running Directly from GitHub](#running-directly-from-github)
  - [RRA Only (Default)](#rra-only-default)
  - [MLE Only](#mle-only)
  - [RRA + MLE Together](#rra--mle-together)
  - [From FASTQ (with Counting)](#from-fastq-with-counting)
  - [From BCL (Full Pipeline)](#from-bcl-full-pipeline)
  - [Using a Parameters File](#using-a-parameters-file)
- [Profiles](#profiles)
  - [Profile Reference](#profile-reference)
  - [Combining Profiles](#combining-profiles)
  - [Docker Profile Details](#docker-profile-details)
  - [Singularity Profile Details](#singularity-profile-details)
  - [SLURM Profile Details](#slurm-profile-details)
  - [Conda Profile Details](#conda-profile-details)
- [Dardel (PDC/KTH HPC)](#dardel-pdckth-hpc)
  - [One-Time Setup](#dardel-one-time-setup)
  - [Interactive Session](#dardel-interactive-session)
  - [Batch Job (SLURM Script)](#dardel-batch-job-slurm)
  - [Using Singularity on Dardel](#dardel-singularity)
- [Environment-Specific Run Scripts](#environment-specific-run-scripts)
- [Pipeline Stages](#pipeline-stages)
- [Output Structure](#output-structure)
- [Parameters Reference](#parameters-reference)
- [Troubleshooting](#troubleshooting)
- [Credits](#credits)

---

## Prerequisites

| Software | Version | Required for |
|---|---|---|
| [Nextflow](https://www.nextflow.io/docs/latest/getstarted.html) | >= 24.04 | All modes |
| [Docker Desktop](https://docs.docker.com/get-docker/) | Any | `-profile docker` |
| [Singularity/Apptainer](https://apptainer.org/) | Any | `-profile singularity` |
| [conda](https://docs.conda.io/projects/conda/latest/user-guide/install/) | >= 23.x | `-profile conda` or Dardel |

Install Nextflow (one-time, any platform):

```bash
# Requires Java 11+
curl -s https://get.nextflow.io | bash
# Or via package manager:
# brew install nextflow          # macOS
# conda install -c bioconda nextflow  # conda
```

Verify installation:

```bash
nextflow info
# Should print version >= 24.04
```

---

## Quick Start

The fastest way to run the pipeline with pre-computed count data:

```bash
# 1. Pull the Docker image
docker pull mobasherbarsi/mageck-kge:0.5.9.5

# 2. Clone the pipeline
git clone https://github.com/MubasherMohammed/kge-nextflow.git
cd kge-nextflow

# 3. Run with 7 comparisons (RRA, ~10 minutes)
nextflow run main.nf -profile docker \
  --count_table all_samples.count.txt \
  --comparisons comparisons.txt \
  --output_dir ./results
```

That is all you need. The interactive HTML report will be at `results/kge_report/mageck.report.html`.

---

## Installation

### Docker (Recommended)

The Docker image comes with everything pre-installed: MAGeCK 0.5.9.5, KGE interactive Plotly reports, pathway enrichment, FLUTE-style gene classification, and all Python/R dependencies.

**Pull from Docker Hub:**

```bash
docker pull mobasherbarsi/mageck-kge:0.5.9.5
```

**Build locally from source:**

```bash
docker build -t mobasherbarsi/mageck-kge:0.5.9.5 .
```

This builds from the `Dockerfile` at the project root, which:
1. Starts from `continuumio/miniconda3:25.3.1-1`
2. Creates the conda environment from `environment.yml`
3. Overlays KGE modifications from `mageck/*.py` onto the installed MAGeCK package
4. Sets `CMD ["mageck", "--help"]` (no `ENTRYPOINT` — see [Docker Profile Details](#docker-profile-details))

### Conda (Local Development)

Use this if you cannot run Docker or want to develop locally:

```bash
git clone https://github.com/MubasherMohammed/kge-nextflow.git
cd kge-nextflow

# Creates the 'mageckenv' environment with MAGeCK + KGE overlays
bash install.sh

# Activate and verify
conda activate mageckenv
mageck --version
```

The `install.sh` script handles all platform detection, including Apple Silicon Rosetta 2 emulation (MAGeCK is x86_64 only) and overlays the KGE modifications onto the installed MAGeCK package.

### Singularity (HPC Clusters)

For HPC clusters where Docker is not available but Singularity/Apptainer is:

**Method A — Pull directly from Docker Hub (recommended):**

```bash
singularity pull docker://mobasherbarsi/mageck-kge:0.5.9.5
# Produces: mageck-kge_0.5.9.5.sif
```

**Method B — Build from the definition file:**

```bash
singularity build mageck-kge.sif Singularity
```

Both methods produce an identical software stack because the Singularity definition boots from the same Docker image.

---

## Input File Formats

### Count Table

Pre-computed sgRNA count matrix. Tab-separated with a gene column followed by sample count columns:

```tsv
sgRNA	Gene	ETP	Control_6d	Mid_6d	High_6d	Control_12d	Low_12d	Mid_12d	High_12d
sgACTB_1	ACTB	1424	1635	1516	1442	1412	1675	1388	1594
sgACTB_2	ACTB	1634	1377	1378	1527	1461	1489	1622	1573
sgACTB_3	ACTB	1482	1557	1578	1610	1509	1596	1594	1435
...
```

- Column 1: sgRNA identifier
- Column 2: Gene symbol
- Columns 3+: Raw read counts (one per sample)

This is the primary input for most runs. Obtain it by running `mageck count` on your FASTQ files, or from an earlier pipeline run.

### Comparisons File (RRA)

Tab-separated file listing treatment-control pairs. Each row produces a separate `mageck test` (RRA) run in parallel:

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

Headers must be exactly `treatment` and `control` (tab-separated, no trailing spaces). Sample names must match the count table column headers exactly.

Template: `assets/comparisons_template.txt`

### Design Matrix (MLE)

Tab-separated file with sample names in column 1 and condition indicators (0/1) in remaining columns:

```tsv
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

- Column 1: **Sample** — must match count table headers exactly
- First condition column: **baseline** — typically 1 for all samples (intercept term)
- Remaining columns: binary indicators (1 = sample has this condition, 0 = does not)

Template: `assets/design_matrix_template.txt`

> **Important for RRA-only runs:** When you provide `--comparisons` without `--design_matrix`, the pipeline automatically injects a `NO_DESIGN_MATRIX` marker file so the HTML report step knows to display only RRA results.

### sgRNA Library File

Required when starting from FASTQ (not needed with a pre-computed `--count_table`). Tab-separated with three columns:

```tsv
sgACTB_1	ACTB	ACGGCGTGACGTGACGTACA
sgACTB_2	ACTB	TCGATCGTACGTACGTACGT
...
```

- Column 1: sgRNA identifier
- Column 2: Target gene symbol
- Column 3: sgRNA spacer sequence

Template: `assets/library_template.txt`

---

## Usage

### Running Directly from GitHub

You do not need to clone the repository. Nextflow can pull the pipeline directly from GitHub:

```bash
nextflow run MubasherMohammed/kge-nextflow -latest -profile docker \
  --count_table all_samples.count.txt \
  --comparisons comparisons.txt \
  --output_dir ./results
```

The `-latest` flag ensures Nextflow pulls the most recent revision from GitHub (otherwise it caches and reuses an older version). Nextflow caches the pipeline at `~/.nextflow/assets/MubasherMohammed/kge-nextflow/`.

When running this way, all file paths must be **absolute** (Nextflow resolves relative paths against the cache directory, not your current working directory):

```bash
# Correct: absolute paths
nextflow run MubasherMohammed/kge-nextflow -latest -profile docker \
  --count_table /full/path/to/all_samples.count.txt \
  --comparisons /full/path/to/comparisons.txt \
  --output_dir /full/path/to/results
```

### RRA Only (Default)

Fastest mode. Each comparison pair runs independently in parallel. 7 comparisons process in ~10 minutes.

```bash
# Docker
nextflow run main.nf -profile docker \
  --count_table all_samples.count.txt \
  --comparisons comparisons.txt \
  --output_dir ./results

# Conda
nextflow run main.nf -profile conda \
  --count_table all_samples.count.txt \
  --comparisons comparisons.txt

# Singularity
nextflow run main.nf -profile singularity \
  --count_table all_samples.count.txt \
  --comparisons comparisons.txt

# Directly from GitHub (Docker)
nextflow run MubasherMohammed/kge-nextflow -latest -profile docker \
  --count_table /abs/path/all_samples.count.txt \
  --comparisons /abs/path/comparisons.txt \
  --output_dir /abs/path/results
```

### MLE Only

Maximum Likelihood Estimation across all conditions jointly. Computationally heavier — 19,000 genes × 8 conditions takes 60–90 minutes.

```bash
nextflow run main.nf -profile docker \
  --count_table all_samples.count.txt \
  --design_matrix design_matrix.txt
```

### RRA + MLE Together

Run both analyses in the same pipeline invocation. Results from both are combined into a single interactive HTML report.

```bash
nextflow run main.nf -profile docker \
  --count_table all_samples.count.txt \
  --comparisons comparisons.txt \
  --design_matrix design_matrix.txt
```

### From FASTQ (with Counting)

Start from raw FASTQ files (skips demultiplexing, runs `mageck count` + RRA/MLE):

```bash
nextflow run main.nf -profile docker \
  --library_file library.txt \
  --fastq_dir ./fastq \
  --comparisons comparisons.txt
```

FASTQ files are matched by the pattern `*{R1,R2}_*{fastq,fastq.gz,fq,fq.gz}`. Files must be named so that `mageck count` can infer sample labels from the filenames, or provide explicit labels with `--sample_labels`.

### From BCL (Full Pipeline)

Start from an Illumina sequencing run folder (BCL files). Requires `bcl-convert` or `bcl2fastq`:

```bash
nextflow run main.nf -profile docker \
  --demultiplex \
  --run_folder /data/illumina_run \
  --sample_sheet SampleSheet.csv \
  --library_file library.txt \
  --comparisons comparisons.txt
```

The pipeline runs: BCL → FASTQ → FastQC → MAGeCK count → RRA/MLE → HTML report.

### Using a Parameters File

For complex runs with many parameters, use a YAML file:

```bash
cp assets/params_template.yml my-params.yml
# Edit my-params.yml with your settings
nextflow run main.nf -profile docker -params-file my-params.yml
```

---

## Profiles

### Profile Reference

| Profile | Pipeline Sourcing | Container | Executor | Use Case | Prerequisites |
|---|---|---|---|---|---|---|
| `docker` | Local `main.nf` or GitHub | Docker containers | local | Local workstation (recommended) | Docker Desktop |
| `conda` | Local `main.nf` or GitHub | Conda environment | local | Local without Docker | conda + `bash install.sh` |
| `singularity` | Local `main.nf` or GitHub | SIF file | local | HPC with Singularity | Singularity/Apptainer |
| `slurm` | Any | None (add with `docker`/`singularity`) | SLURM | HPC cluster | SLURM workload manager |
| `dardel` | Any | Conda environment | local | PDC/KTH Dardel | Dardel modules (see below) |

### Combining Profiles

Profiles can be combined by separating them with commas. Process-level settings (container, executor) merge additively:

```bash
# Singularity containers on SLURM (HPC cluster)
nextflow run main.nf -profile singularity,slurm \
  --count_table all_samples.count.txt \
  --comparisons comparisons.txt
```

In this combination, each process runs inside a Singularity container but is dispatched to the SLURM queue instead of running locally.

### Docker Profile Details

The `docker` profile enables Docker for all processes. It uses `mobasherbarsi/mageck-kge:0.5.9.5` for MAGeCK processes, and the corresponding `quay.io/biocontainers/` images for BCL conversion, FastQC, and MultiQC.

**Why no `ENTRYPOINT`:** The Docker image intentionally has no `ENTRYPOINT`. Nextflow runs process scripts via `docker run ... bash -c "<command>"`. An `ENTRYPOINT` like `mageck` would prepend itself to every command (e.g., `mageck bash -c "fastqc ..."`) and break non-mageck processes. The `PATH` is already set to include the conda environment with mageck.

**Resource allocations per process:**

| Process | CPUs | Memory | Time |
|---|---|---|---|
| DEMULTIPLEX | 8 | 32 GB | 48 h |
| FASTQC_READS | 2 | 4 GB | — |
| MAGECK_COUNT | 4 | 16 GB | 24 h |
| MAGECK_TEST_RRA | 4 | 16 GB | — |
| MAGECK_MLE_ANALYSIS | configurable (`--threads`) | 16 GB | — |
| KGE_REPORT | 2 | 8 GB | — |

Override these in your own config or via `-process.withName:PROCESS_NAME.cpus=8`.

### Singularity Profile Details

The `singularity` profile enables Singularity for all processes. It works identically to Docker — the SIF file contains the same software stack since it boots from the same Docker image.

**Building the SIF file:**

```bash
# Method 1: Pull directly from Docker Hub (no definition file needed)
singularity pull docker://mobasherbarsi/mageck-kge:0.5.9.5

# Method 2: Build from the Singularity definition file
singularity build mageck-kge.sif Singularity

# Method 3: Build from Docker Hub via definition file
singularity build mageck-kge.sif docker://mobasherbarsi/mageck-kge:0.5.9.5
```

> The SIF file is a single, self-contained binary image. Move it anywhere and reference it with `singularity run` or let Nextflow's `-profile singularity` discover it automatically if it is in the current directory. Nextflow also pulls the Docker image automatically if no local SIF is found.

**Why no `%runscript`:** The Singularity definition has no `%runscript` for the same reason the Docker image has no `ENTRYPOINT`. Nextflow uses `singularity exec` (not `singularity run`), which bypasses the runscript entirely.

### SLURM Profile Details

The `slurm` profile sets the executor to `slurm` without configuring a container. It must be combined with `docker` or `singularity`:

```bash
# Singularity containers + SLURM scheduling
nextflow run main.nf -profile singularity,slurm \
  --count_table all_samples.count.txt \
  --comparisons comparisons.txt

# Docker + SLURM (only if Docker is available on compute nodes)
nextflow run main.nf -profile docker,slurm \
  --count_table all_samples.count.txt \
  --comparisons comparisons.txt
```

Each process is submitted as a SLURM job with `--time=48:00:00` and `--partition=normal`. Override with `-process.queue=myqueue -process.time=72.h`.

### Conda Profile Details

The `conda` profile uses the local conda environment defined in `environment.yml`. **Important:** Nextflow creates the environment automatically from `environment.yml`, but you must run `bash install.sh` afterwards to overlay the KGE modifications:

```bash
# Step 1: Create/update the conda environment
conda env create -f environment.yml -n mageckenv

# Step 2: Overlay KGE modifications
bash install.sh mageckenv

# Step 3: Run the pipeline
nextflow run main.nf -profile conda \
  --count_table all_samples.count.txt \
  --comparisons comparisons.txt
```

---

## Dardel (PDC/KTH HPC)

### Dardel: One-Time Setup

Run this once on Dardel to create the `mageckenv` conda environment with KGE overlays:

```bash
# Clone the pipeline
git clone https://github.com/MubasherMohammed/kge-nextflow.git
cd kge-nextflow

# Run the Dardel installer
bash install_dardel.sh
```

This script:
1. Loads the required Dardel modules (PDC, bioinfo-tools, Java 11, miniconda3, Nextflow, Singularity)
2. Creates the `mageckenv` conda environment from `environment.yml`
3. Overlays KGE modifications from `mageck/*.py` onto the installed MAGeCK package
4. Verifies the installation

If module versions need updating, check available versions:

```bash
module spider PDC
module spider miniconda3
module spider nextflow
module spider singularity
```

Then edit `install_dardel.sh` or use the manual steps below.

### Dardel: Interactive Session

For testing or small runs, use an interactive session on a compute node:

```bash
# Request an interactive node (adjust time/resources as needed)
salloc -A <your-project> --nodes=1 --time=01:00:00

# On the compute node — load all required modules
ml PDC/23.12
ml bioinfo-tools
ml java/11
ml miniconda3/25.3.1-1-cpeGNU-24.11
ml nextflow/24.04.2
ml singularity/4.1.1-cpeGNU-23.12

# Activate the KGE conda environment
source activate mageckenv

# Run the pipeline
nextflow run main.nf -profile dardel \
  --count_table /path/to/all_samples.count.txt \
  --comparisons /path/to/comparisons.txt \
  --output_dir /path/to/results
```

> **Note:** Both `nextflow/24.04.2` and `Nextflow/22.10.1` are available on Dardel. The pipeline requires Nextflow >= 24.04 (DSL2), so use `nextflow/24.04.2`. The older `Nextflow/22.10.1` does not support this pipeline.

### Dardel: Batch Job (SLURM Script)

For production runs, create a SLURM submission script:

```bash
#!/bin/bash
#SBATCH -A <your-project>
#SBATCH -J kge_pipeline
#SBATCH --nodes=1
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --output=kge_%j.out
#SBATCH --error=kge_%j.err

# Load Dardel modules — order matters (PDC first, then specific tools)
ml PDC/23.12
ml bioinfo-tools
ml java/11
ml miniconda3/25.3.1-1-cpeGNU-24.11
ml nextflow/24.04.2
ml singularity/4.1.1-cpeGNU-23.12

# Activate the KGE conda environment
source activate mageckenv

# Run the pipeline
nextflow run /path/to/kge-nextflow/main.nf \
  -profile dardel \
  -work-dir /path/to/work \
  --count_table /path/to/all_samples.count.txt \
  --comparisons /path/to/comparisons.txt \
  --design_matrix /path/to/design_matrix.txt \
  --output_dir /path/to/results
```

Submit with:

```bash
sbatch run_kge_dardel.sh
```

Notes for Dardel:
- Use `-work-dir` to specify a scratch location with fast I/O (e.g., `/cfs/klemming/scratch/$USER/work`)
- The `dardel` profile uses the `local` executor because Dardel is a single-node system for most jobs. For multi-node needs, combine profiles: `-profile dardel,slurm`
- Module versions may change over time. Verify available versions with `module spider <name>` and update accordingly:
  ```bash
  module spider PDC
  module spider miniconda3
  module spider nextflow
  module spider singularity
  module spider java
  ```
- Dardel uses Klemming storage; store reference data under `/cfs/klemming/projects/<project>/`
- The pipeline requires Nextflow >= 24.04 (DSL2). An older module `Nextflow/22.10.1` is also available on Dardel but is **not compatible** — always use `nextflow/24.04.2`
- The `bioinfo-tools` module may show a legacy UPPMAX note — this is harmless and does not affect pipeline execution
- If `module load java/11` fails, run `module spider java` to find the exact Java module name on your Dardel allocation and adjust accordingly

**Ready-to-use batch script:** A template SLURM submission script is included in the repository:

```bash
# Edit paths and project ID, then submit:
sbatch run_kge_dardel_singularity.sh
```

This script runs the pipeline directly from GitHub (`MubasherMohammed/kge-nextflow`) with `-profile singularity,slurm`, loads all required modules, pulls the SIF image, and summarises results. See `run_kge_dardel_singularity.sh` in the project root.

### Dardel: Using Singularity

Singularity lets you run the pipeline with zero conda setup — the SIF image contains everything. You still need Nextflow and Java for the pipeline orchestration, but all MAGeCK/KGE dependencies are in the container.

**One-time SIF pull:**

```bash
# On a login node or build node:
singularity pull docker://mobasherbarsi/mageck-kge:0.5.9.5
# Produces: mageck-kge_0.5.9.5.sif
```

**Interactive session with Singularity + conda (conda provides Nextflow only):**

```bash
salloc -A <your-project> --nodes=1 --time=01:00:00

# On the compute node:
ml PDC/23.12
ml bioinfo-tools
ml java/11
ml miniconda3/25.3.1-1-cpeGNU-24.11
ml nextflow/24.04.2
ml singularity/4.1.1-cpeGNU-23.12

# Conda environment provides only Nextflow for orchestration
# MAGeCK runs inside the Singularity container automatically
nextflow run main.nf -profile singularity,slurm \
  --count_table /path/to/all_samples.count.txt \
  --comparisons /path/to/comparisons.txt \
  --output_dir /path/to/results
```

**Batch job with Singularity (recommended for production):**

```bash
#!/bin/bash
#SBATCH -A <your-project>
#SBATCH -J kge_singularity
#SBATCH --nodes=1
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --output=kge_%j.out
#SBATCH --error=kge_%j.err

# Load modules — only Nextflow (for orchestration) and Singularity (for containers)
# are needed; the SIF image has MAGeCK/KGE built in
ml PDC/23.12
ml bioinfo-tools
ml java/11
ml miniconda3/25.3.1-1-cpeGNU-24.11
ml nextflow/24.04.2
ml singularity/4.1.1-cpeGNU-23.12

# Run with singularity+slurm profiles
# Nextflow auto-discovers the SIF from the Docker image name in nextflow.config
nextflow run /path/to/kge-nextflow/main.nf \
  -profile singularity,slurm \
  -work-dir /path/to/work \
  --count_table /path/to/all_samples.count.txt \
  --comparisons /path/to/comparisons.txt \
  --output_dir /path/to/results
```

> **Tip:** You can use `module load singularity` (generic) or `module load singularity/4.1.1-cpeGNU-23.12` (specific version). The generic load picks whatever default is available on your Dardel allocation.

---

## Environment-Specific Run Scripts

For convenience, create a wrapper script in your project directory:

```bash
#!/bin/bash
# run_mageck.sh — Run the KGE pipeline with Docker (local workstation)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

nextflow run MubasherMohammed/kge-nextflow -latest -profile docker \
  --count_table "${SCRIPT_DIR}/all_samples.count.txt" \
  --comparisons "${SCRIPT_DIR}/comparisons.txt" \
  --output_dir "${SCRIPT_DIR}/results"
```

Then run with:

```bash
bash run_mageck.sh
```

Using `$SCRIPT_DIR` for paths avoids Nextflow's relative-path resolution issue (relative paths are resolved against the pipeline cache directory `~/.nextflow/assets/`, not the current directory).

---

## Pipeline Stages

| Stage | Tool | Description |
|---|---|---|
| DEMULTIPLEX | bcl-convert / bcl2fastq | BCL → FASTQ conversion (Illumina run folder) |
| FASTQC | FastQC | Pre-alignment quality control on raw reads |
| MAGECK COUNT | mageck count | sgRNA read counting, normalization, QC summary |
| MAGECK TEST | mageck test | RRA statistical test — one run per comparison pair (parallel) |
| MAGECK MLE | mageck mle | Maximum Likelihood Estimation — multi-condition analysis |
| KGE REPORT | mageck report | Interactive Plotly HTML report combining all results |
| MULTIQC | MultiQC | Aggregated QC report (FastQC + count summary) |

---

## Output Structure

```
results/
├── mageck_test/                # RRA results (one file set per comparison)
│   ├── ETP_vs_Control_6d.gene_summary.txt
│   ├── ETP_vs_Control_6d.sgrna_summary.txt
│   ├── Mid_6d_vs_Control_6d.gene_summary.txt
│   ├── Mid_6d_vs_Control_6d.sgrna_summary.txt
│   └── ...                     # One pair per comparison
├── mageck_mle/                 # MLE results (if --design_matrix provided)
│   ├── mageck.gene_summary.txt
│   └── mageck.sgrna_summary.txt
├── kge_report/                 # Interactive HTML report
│   └── mageck.report.html      # Plotly-based, ~27 MB for 7 comparisons
└── multiqc/                    # QC reports (if FASTQ input)
    └── multiqc_report.html
```

Output file descriptions:

- **`gene_summary.txt`**: One row per gene. Columns include `neg|score`, `neg|p-value`, `neg|fdr`, `pos|score`, `pos|p-value`, `pos|fdr`, `gene_id`, and gene-level LFC. This is your primary result — ranked gene list of hits.
- **`sgrna_summary.txt`**: One row per sgRNA. Columns include `sgrna`, `gene`, `control_count`, `treatment_count`, `LFC`, `score`, `p-value`, `fdr`, `high_in_treatment`. Use this for sgRNA-level inspection.
- **`mageck.report.html`**: Interactive Plotly report with volcano plots, gene rankings, sgRNA-level details, pathway enrichment (if enabled), and FLUTE-style gene classification.

---

## Parameters Reference

### Input Parameters

| Parameter | Default | Description |
|---|---|---|
| `--count_table` | `''` | Pre-computed count table (skips demultiplexing + counting) |
| `--comparisons` | `''` | TSV with treatment/control pairs → triggers RRA |
| `--design_matrix` | `''` | MLE design matrix → triggers MLE |
| `--fastq_dir` | `''` | Directory with FASTQ files (triggers counting mode) |
| `--demultiplex` | `false` | Enable BCL → FASTQ demultiplexing |
| `--run_folder` | `''` | Illumina run folder (BCL directory, required for demultiplexing) |
| `--sample_sheet` | `''` | SampleSheet.csv path (required for demultiplexing) |
| `--bcl_converter` | `'bcl-convert'` | `'bcl-convert'` or `'bcl2fastq'` |
| `--library_file` | `''` | sgRNA library file (required for FASTQ/demux modes) |
| `--sample_labels` | `''` | Comma-separated sample labels (overrides auto-detection) |

### MAGeCK Count Parameters

| Parameter | Default | Description |
|---|---|---|
| `--norm_method` | `'median'` | Normalization: `none`, `median`, `total`, `control` |
| `--control_sgrna` | `''` | File with control sgRNA list |
| `--control_gene` | `''` | File with control gene list |
| `--sgrna_len` | `20` | sgRNA length |
| `--trim5` | `'AUTO'` | 5' trim length or `'AUTO'` |
| `--count_n` | `false` | Count sgRNAs containing Ns |
| `--reverse_complement` | `false` | Reverse complement library sequences |

### MAGeCK Test (RRA) Parameters

| Parameter | Default | Description |
|---|---|---|
| `--adjust_method` | `'fdr'` | `'fdr'`, `'holm'`, `'pounds'` |
| `--gene_test_fdr_threshold` | `0.25` | FDR threshold for gene-level testing |
| `--remove_zero` | `'both'` | `'none'`, `'control'`, `'treatment'`, `'both'`, `'any'` |
| `--gene_lfc_method` | `'median'` | `'median'`, `'mean'`, `'alphamedian'`, `'alphamean'`, `'secondbest'` |

### MAGeCK MLE Parameters

| Parameter | Default | Description |
|---|---|---|
| `--include_samples` | `''` | Comma-separated sample labels for MLE |
| `--beta_labels` | `''` | Comma-separated beta labels |
| `--threads` | `1` | Threads for MLE |
| `--permutation_round` | `2` | Permutation rounds for MLE |

### HTML Report Parameters

| Parameter | Default | Description |
|---|---|---|
| `--html_report` | `true` | Generate interactive HTML report |
| `--skip_enrichment` | `false` | Skip pathway enrichment analysis |
| `--enrichment_top_n` | `50` | Top N genes for pathway enrichment |
| `--enrichment_fdr` | `0.05` | FDR threshold for enrichment significance |
| `--organism` | `'human'` | `'human'` or `'mouse'` |
| `--fdr_threshold` | `0.05` | FDR threshold for volcano/rank plots |
| `--top_n` | `20` | Number of top genes to label in plots |

### QC Parameters

| Parameter | Default | Description |
|---|---|---|
| `--fastqc` | `true` | Run FastQC |
| `--multiqc` | `true` | Run MultiQC |

### Output Parameters

| Parameter | Default | Description |
|---|---|---|
| `--output_dir` | `'./results'` | Output directory |
| `--output_prefix` | `'mageck'` | Output file prefix |

Full parameter reference with defaults: `assets/params_template.yml`

---

## Troubleshooting

### "no such file or directory" for docker.sock

Docker Desktop is installed but the daemon is not running. Start Docker Desktop (from Applications or `open -a Docker`) and wait for the whale icon to stop animating.

### Nextflow resolves relative file paths to the cache directory

When running with `nextflow run MubasherMohammed/kge-nextflow`, relative paths like `--count_table ./file.txt` are resolved against `~/.nextflow/assets/MubasherMohammed/kge-nextflow/`, not your current directory.

**Fix:** Always use absolute paths, or define `SCRIPT_DIR` in a wrapper script:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
nextflow run ... --count_table "${SCRIPT_DIR}/file.txt"
```

### Pipeline uses a stale cached version

If you updated the pipeline on GitHub but Nextflow is running an old version, use the `-latest` flag:

```bash
nextflow run MubasherMohammed/kge-nextflow -latest -profile docker ...
```

To force a complete refresh, delete the cache:

```bash
rm -rf ~/.nextflow/assets/MubasherMohammed/kge-nextflow
```

### "Graphviz is required to render the execution DAG"

This is a harmless warning. Execution graphs are disabled by default. To suppress it:

```bash
nextflow run main.nf -profile docker ... -dag disabled
```

### MLE is very slow (60-90 minutes)

MLE on 19,000 genes × 8 conditions is computationally heavy. Strategies:
- Use RRA-only mode if MLE is not needed (`--comparisons` without `--design_matrix`)
- Increase `--threads` to parallelize MLE matrix operations
- Request a node with more CPUs for MLE: `-process.withName:MAGECK_MLE_ANALYSIS.cpus=8`

### Conda environment exists but pipeline errors with "mageck: command not found"

The conda environment was created from `environment.yml` but the KGE overlays were not applied. Run:

```bash
bash install.sh mageckenv
```

This copies the modified Python source files from `mageck/*.py` to the MAGeCK site-packages directory.

### Singularity: "permission denied" or SIF build fails on macOS

Singularity does not run natively on macOS. Build the SIF on a Linux machine or HPC cluster. Alternatively, pull the SIF directly from Docker Hub:

```bash
singularity pull docker://mobasherbarsi/mageck-kge:0.5.9.5
```

This only requires Singularity and network access — no Docker daemon needed.

---

## Credits

- **MAGeCK** — Wei Li, Han Xu, Xiaole Liu lab (BSD License)
- **KGE enhancements** — Interactive Plotly reports, pathway enrichment, FLUTE-style gene classification
- **Pipeline framework** — Nextflow (DSL2)
