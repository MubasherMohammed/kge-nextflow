Bootstrap: docker
From: mubasher/mageck-kge:0.5.9.5

%labels
    org.opencontainers.image.title MAGeCK-KGE
    org.opencontainers.image.description MAGeCK with KGE interactive Plotly HTML reports for CRISPR screen analysis
    org.opencontainers.image.version 0.5.9.5
    org.opencontainers.image.authors Mubasher Mohammed

%post
    echo "MAGeCK-KGE Singularity image ready"

%environment
    export PATH=/opt/conda/envs/mageckenv/bin:${PATH}

%runscript
    mageck "$@"