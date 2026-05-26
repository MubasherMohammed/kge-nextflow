Bootstrap: docker
From: mobasherbarsi/mageck-kge:0.5.9.5

%labels
    org.opencontainers.image.title MAGeCK-KGE
    org.opencontainers.image.description MAGeCK with KGE interactive Plotly HTML reports for CRISPR screen analysis
    org.opencontainers.image.version 0.5.9.5
    org.opencontainers.image.authors Mubasher Mohammed

%post
    # Verify that the conda environment and mageck are available
    # (the Docker base image should already have everything installed)
    if command -v mageck &>/dev/null; then
        echo "MAGeCK $(mageck --version 2>&1 | head -1) found in PATH"
    else
        echo "WARNING: mageck not found in PATH — check Docker base image"

        # Fallback: if we have conda but mageck isn't in PATH, find it
        if command -v conda &>/dev/null; then
            echo "Attempting to locate mageck via conda..."
            CONDA_ENVS=$(conda env list | grep -oP '^\S+' | grep -v '^#' | grep -v '^$')
            for env in $CONDA_ENVS; do
                ENV_PATH=$(conda run -n "$env" which mageck 2>/dev/null || true)
                if [ -n "$ENV_PATH" ]; then
                    echo "Found mageck in conda env: $env at $ENV_PATH"
                    ENV_BIN=$(dirname "$ENV_PATH")
                    echo "export PATH=${ENV_BIN}:\$PATH" >> "$SINGULARITY_ENVIRONMENT"
                    break
                fi
            done
        fi
    fi

%environment
    export PATH=/opt/conda/envs/mageckenv/bin:${PATH}

# NOTE: No %runscript block. Nextflow uses `singularity exec` (not `singularity run`)
# which bypasses the runscript entirely. An entrypoint-like runscript would interfere
# with Nextflow process execution in the same way as a Docker ENTRYPOINT.
# Use `singularity run` interactively to invoke mageck directly.