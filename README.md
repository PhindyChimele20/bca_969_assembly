#  README

## 1. Data sources

This task is based on on publicly available sequencing data from the study "Genome assembly, comparative genomics, and identification of genes/pathways underlying plant growth-promoting traits of an actinobacterial strain, Amycolatopsis sp. (BCA-696)" which focused on generating the draft genome sequence of an agriculturally important actinobacterial species Amycolatopsis sp. BCA-696 and characterizing it. Approximately 9.905 million paired-end (100 bp × 2) and ~ 6.242 million mate pair (250 bp × 2) reads were sequenced on the Illumina HiSeq 2500.

---

## 2. How to download

The data for the sample is available as raw reads are available on NICB under Bioproject ID: PRJNA765508.
### Code for downloading

```bash
SRRS=("SRR25722949")

for SRR in "${SRRS[@]}"; do
    echo "Downloading $SRR ..."
    prefetch "$SRR"
    fastq-dump --gzip --split-files "$SRR"
done
```


---

## 3. Pre-processing 

Miniarization was done by compressing the fastq reads using zip

1. **STEP 1** ...

```bash
gunzip *.fastq.gz
for file in *.fastq; do
 zip "${file}.zip" "$file"; done
```


---

## 4. How the workflow works
The workflow files is stored in workflow/ and it is divided into different steps:
The workflow files are stored in `workflow/`.

---

### Step 1 – Quality Check

**Purpose:** The workflow takes each FASTQ.qz file (raw reads), assess the quality of the reads and give the scores and overall stats on the quality of reads.
**Tools:** `fastqc`
**Inputs:** Raw reads FASTQ files (from `data/`)
**Outputs:** quality matrix (html)
**Command:**

```bash
# Input data
READS_PE1="SRR25722949_1.fastq.gz"
READS_PE2="SRR25722949_2.fastq.gz"
OUTDIR="genome_assembly_pipeline"
THREADS=16

mkdir -p $OUTDIR
cd $OUTDIR

# Step 1: Raw Quality Check (FastQC)
echo ">>> Running FastQC on raw reads..."
mkdir -p fastqc_raw
fastqc -t $THREADS $READS_PE1 $READS_PE2 -o fastqc_raw                                      

```

---

### Step 2 - Reads Cleaning/Trimming

**Purpose:** Process reads to get clean, high-quality reads
**Tools:** 'Trimmomatic'
**Inputs:** fastq.gz files
**Outputs:** trimmed fastq.gz files
**Command:**

```bash
echo ">>> Running Trimmomatic..."
TRIM_JAR=/apps/chpc/bio/trimmomatic/0.39/trimmomatic-0.39.jar

java -jar $TRIM_JAR PE -threads $THREADS \
   $PBS_O_WORKDIR/$READS_PE1 $PBS_O_WORKDIR/$READS_PE2 \
   trimmed_R1_paired.fq.gz trimmed_R1_unpaired.fq.gz \
   trimmed_R2_paired.fq.gz trimmed_R2_unpaired.fq.gz \
   ILLUMINACLIP:/apps/chpc/bio/trimmomatic/0.39/adapters/TruSeq3-PE.fa:2:30:10 \
   SLIDINGWINDOW:4:20 MINLEN:50
```
---

### Step 3 –  Post-trimming Quality Check 

**Purpose:** The workflow takes each trimmed FASTQ.qz file , assess the quality of the reads and give the scores and overall stats on the quality of trimmed reads.
**Tools:** 'fastqc'
**Inputs:** trimmed fastq reads
**Outputs:** quality matrix (html)
**Command:**
```bash
echo ">>> Running FastQC on trimmed reads..."
mkdir -p fastqc_trimmed
fastqc -t $THREADS trimmed_R1_paired.fq.gz trimmed_R2_paired.fq.gz -o fastqc_trimmed

```
### Step 4 - Assembly with SOAPdenovo

**Purpose:** This part of the workflow assembly the genome using SOAPdenovo to form contigs
**Tools:** 'SOAPdenovo'
**Inputs:** .trimmed.fastq files/reads, config_file.txt
**Outputs:** .fasta
**Command:**

```bash
if [ ! -f $PBS_O_WORKDIR/config_file.txt ]; then
  echo "ERROR: config_file.txt not found in $PBS_O_WORKDIR"
  exit 1
fi

echo ">>> Running SOAPdenovo..."
SOAPdenovo-127mer all -s $PBS_O_WORKDIR/config_file.txt -K 63 -R -o soapdenovo_out -p $THREADS


```
---
### Step 5 - Assembly with SPAdes

**Purpose:** This part of the workflow assemble the genome using SPAdes to form contigs
**Tools:** 'Spades'
**Inputs:** trimmed fastq reads
**Outputs:** .fasta file
**Command:**

```bash
echo ">>> Running SPAdes..."
spades.py -1 trimmed_R1_paired.fq.gz -2 trimmed_R2_paired.fq.gz \
   -o spades_out -t $THREADS -m 60

```
---

### Step 6 - Assess assemblies with QUAST

**Purpose:** This part of the workflow uses quast to assess the quality of the assembled genomes
**Tools:** 'QUAST'
**Inputs:** .fasta
**Outputs:** html, .txt file
**Command:**

```bash
if [ -f spades_out/scaffolds.fasta ]; then
    echo ">>> Running QUAST..."
    quast.py soapdenovo_out.scafSeq spades_out/scaffolds.fasta -o quast_out -t $THREADS
else
    echo "WARNING: SPAdes output not found, skipping QUAST"
fi

```
---
### Step 7 - Step 7: Filter contigs <500 bp

**Purpose:** This part of the workflow filters contigs that are less than 500 bp, for contiguity and to ensure quality of assembly
**Tools:** 'bash/awk'
**Inputs:** scaffolds.fasta
**Outputs:** filtered.fasta
**Command:**

```bash
if [ -f spades_out/scaffolds.fasta ]; then
    echo ">>> Filtering contigs <500bp..."
    awk '/^>/ {if (seqlen>=500) print seqname"\n"seq; seq=""; seqlen=0; seqname=$0}
         /^[^>]/ {seqlen+=length($0); seq=seq$0}
         END {if (seqlen>=500) print seqname"\n"seq}' spades_out/scaffolds.fasta > filtered_contigs.fasta
else
    echo "WARNING: No SPAdes scaffolds to filter"
fi

echo ">>> Pipeline finished at $(date)"

```
---
