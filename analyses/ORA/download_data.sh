if [ ! -f "GCF_000009045.1_ASM904v1_genomic.gff.gz" ]; then
    wget -O GCF_000009045.1_ASM904v1_genomic.gff.gz https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/009/045/GCF_000009045.1_ASM904v1/GCF_000009045.1_ASM904v1_genomic.gff.gz
    gunzip -k GCF_000009045.1_ASM904v1_genomic.gff.gz
fi

