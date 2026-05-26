#!/bin/bash
# =============================================================================
# Batch job for Dardel (PDC/KTH) — KGE pipeline via Singularity + SLURM
# Runs directly from GitHub (no clone needed).
#
# Usage:
#   1. Edit <your-project> and file paths below to match your Dardel allocation.
#   2. Submit:
#        sbatch run_kge_dardel_singularity.sh
#
# This script runs the same RRA test as the local Docker test:
#   7 comparisons × RRA → KGE interactive HTML report
# =============================================================================

#SBATCH -A <your-project>
#SBATCH -J kge_test_singularity
#SBATCH --nodes=1
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --output=kge_%j.out
#SBATCH --error=kge_%j.err

set -euo pipefail

# =============================================================================
# 1. Load Dardel modules
# =============================================================================
ml PDC/23.12
ml bioinfo-tools
ml java/OracleJDK_11.0.9
ml miniconda3/25.3.1-1-cpeGNU-24.11
ml nextflow/24.04.2
ml singularity/4.1.1-cpeGNU-23.12

echo "=== Modules loaded ==="
echo "  Nextflow: $(nextflow -v 2>&1)"
echo "  Java:     $(java -version 2>&1 | head -1)"
echo "  Singularity: $(singularity --version 2>&1)"

# =============================================================================
# 2. Configure paths — EDIT THESE for your Dardel allocation
# =============================================================================
PROJECT_DIR="/cfs/klemming/projects/<your-project>"

# Test data (Rong_data nf_test — adjust paths to where you copied the files)
COUNT_TABLE="${PROJECT_DIR}/Rong_data/nf_test/all_samples.count.txt"
COMPARISONS="${PROJECT_DIR}/Rong_data/nf_test/comparisons.txt"
OUTPUT_DIR="${PROJECT_DIR}/Rong_data/nf_test/results_singularity"
WORK_DIR="${PROJECT_DIR}/work"   # fast scratch I/O

echo "=== Configuration ==="
echo "  Count table:  ${COUNT_TABLE}"
echo "  Comparisons:  ${COMPARISONS}"
echo "  Output dir:   ${OUTPUT_DIR}"
echo "  Work dir:     ${WORK_DIR}"

# =============================================================================
# 3. Verify input files exist
# =============================================================================
if [ ! -f "${COUNT_TABLE}" ]; then echo "ERROR: count table not found"; exit 1; fi
if [ ! -f "${COMPARISONS}" ]; then echo "ERROR: comparisons file not found"; exit 1; fi

# =============================================================================
# 4. Pull the SIF image (one-time — comment out after first run)
# =============================================================================
echo "=== Pulling Singularity image ==="
singularity pull --force docker://mobasherbarsi/mageck-kge:0.5.9.5

# =============================================================================
# 5. Run the pipeline directly from GitHub
# =============================================================================
echo "=== Starting KGE pipeline ==="
echo "  Mode: RRA only (7 comparisons)"
echo "  Started: $(date)"

nextflow run MubasherMohammed/kge-nextflow \
  -latest \
  -profile singularity,slurm \
  -work-dir "${WORK_DIR}" \
  --count_table "${COUNT_TABLE}" \
  --comparisons "${COMPARISONS}" \
  --output_dir "${OUTPUT_DIR}"

echo "=== Pipeline finished: $(date) ==="

# =============================================================================
# 6. Summarise results
# =============================================================================
echo ""
echo "=== Results ==="
if [ -d "${OUTPUT_DIR}" ]; then
    echo "  Output directory: ${OUTPUT_DIR}"
    ls -lh "${OUTPUT_DIR}/mageck_test/" 2>/dev/null || echo "  (no mageck_test/ — check logs)"
    ls -lh "${OUTPUT_DIR}/kge_report/" 2>/dev/null || echo "  (no kge_report/ — check logs)"
else
    echo "  Output directory not found — pipeline may have failed."
fi

echo ""
echo "=== Done ==="
