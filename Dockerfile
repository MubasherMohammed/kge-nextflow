# ============================================================================
# Dockerfile for MAGeCK-KGE: CRISPR screen analysis with interactive HTML reports
# ============================================================================
# Build:
#   docker build -t mubasher/mageck-kge:0.5.9.5 .
# Push:
#   docker push mubasher/mageck-kge:0.5.9.5
# ============================================================================

FROM continuumio/miniconda3:25.3.1-1 AS base

LABEL org.opencontainers.image.title="MAGeCK-KGE"
LABEL org.opencontainers.image.description="MAGeCK with KGE interactive Plotly HTML reports for CRISPR screen analysis"
LABEL org.opencontainers.image.version="0.5.9.5"
LABEL org.opencontainers.image.authors="Mubasher Mohammed"
LABEL org.opencontainers.image.source="https://github.com/MubasherMohammed/kge-nextflow"

ENV CONDA_ENV=mageckenv
ENV CONDA_DIR=/opt/conda
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# ---------------------------------------------------------------------------
# Create conda environment with MAGeCK + dependencies
# ---------------------------------------------------------------------------
COPY environment.yml /tmp/environment.yml

RUN conda config --add channels bioconda && \
    conda config --add channels conda-forge && \
    conda config --set channel_priority strict && \
    conda env create -f /tmp/environment.yml -n ${CONDA_ENV} && \
    conda clean -afy

# ---------------------------------------------------------------------------
# Overlay KGE modifications (enhanced HTML report, pathway enrichment)
# ---------------------------------------------------------------------------
COPY mageck/ /tmp/kge/mageck/

RUN MAGECK_DIR=$(${CONDA_DIR}/envs/${CONDA_ENV}/bin/python -c "import mageck; print(mageck.__file__)" | xargs dirname) && \
    cp /tmp/kge/mageck/*.py "${MAGECK_DIR}/" && \
    cp /tmp/kge/mageck/*.gmt "${MAGECK_DIR}/" && \
    cp /tmp/kge/mageck/*.txt "${MAGECK_DIR}/" && \
    cp /tmp/kge/mageck/*.Rnw "${MAGECK_DIR}/" 2>/dev/null || true && \
    cp /tmp/kge/mageck/*.Rmd "${MAGECK_DIR}/" 2>/dev/null || true && \
    cp /tmp/kge/mageck/*.RTemplate "${MAGECK_DIR}/" 2>/dev/null || true && \
    rm -rf "${MAGECK_DIR}/__pycache__" /tmp/kge && \
    echo "KGE modifications installed to ${MAGECK_DIR}"

# ---------------------------------------------------------------------------
# Make conda env the default PATH
# ---------------------------------------------------------------------------
ENV CONDA_DEFAULT_ENV=${CONDA_ENV}
ENV PATH=/opt/conda/envs/${CONDA_ENV}/bin:${PATH}

# Verify installation
RUN mageck --version && \
    python -c "from mageck.htmlReport import mageck_report_main; print('KGE HTML report: OK')" && \
    python -c "import plotly; print(f'Plotly {plotly.__version__}: OK')"

# Default working directory for pipeline runs
WORKDIR /data

# NOTE: No ENTRYPOINT set intentionally.
# Nextflow runs process scripts via `bash -c` inside containers, so an ENTRYPOINT
# like `mageck` would prepend itself to every command (e.g. `mageck bash -c "fastqc ..."`)
# and break non-mageck processes. The PATH already points to the conda env with mageck.

# Default command — shows help when container is run interactively
CMD ["mageck", "--help"]