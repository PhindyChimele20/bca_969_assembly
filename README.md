#  README

## 1. Data sources

This task is based on on publicly available sequencing data from the study "Genomic characterization of Enterobacter sp. PGRG2 and Achromobacter insolitus PGRG5: bacterial strains isolated from soil present near electronics manufacture industry for heavy metal remediation" which focused on generating whole-genome sequence of PGRG5 and the draft genome sequence of PGRG2 strains isolated from electronic waste contaminated soil. Whole genome sequencing was done on both extracted strains where a sequencing library with paired-end reads (2 × 150 bp) was created and subsequently subjected to sequencing on the NovaSeq 6000 platform provided by Illumina (3). For this analysis only PGRG5 strain was used where the fastq forward and reverse reads are used as the inputs for the workflow.

---

## 2. How to download

The data for the sample is available as raw reads are available at DDBJ/ENA/GenBank under the BioProject with the Bioproject no. PRJNA981674 and SRA accession SRR25007833.
### Code for downloading

```bash
geofetch -i GSE296035 --just-metadata
SRRS=("SRR25007833")

for SRR in "${SRRS[@]}"; do
    echo "Downloading $SRR ..."
    prefetch "$SRR"
    fastq-dump --gzip --split-files "$SRR"
done
```


---

## 3. Pre-processing 

From the GEO where the raw data fastq files are, we selected 3 samples and downloaded using their SRR accessions as per above script (Code for Downloaded)

1. **STEP 1** ...

Example:

```bash
CODE TO SUBSAMPLE
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
module load fastqc-0.11.7
WKD="/data/Microbial_Genomics_PGRG5"
cd $WKD

fastqc -o "/data/Microbial_Genomics_PGRG5" PGRG5_R1.fq.1 PGRG5_R2.fq.1                                          

```

---

### Step 2 - Reads Cleaning/Trimming

**Purpose:** Process reads to get clean, high-quality reads
**Tools:** 'Trimmomatic'
**Inputs:** fastq.gz files
**Outputs:** trimmed fastq.gz files
**Command:**

```bash
#Run Trimmomatic on paired-end reads
java -jar $TRIMMOMATIC \
PE -phred33 -validatePairs PGRG5_R1.fq.1 PGRG5_R2.fq.1 PGRG5_R1.trim.fq.1  PGRG5_R1.unpaired.fq.1 PGRG5_R2.trim.fq.1 PGRG5_R2.unpaired.fq.1 LEADING:25 TRAILING:25 SLIDINGWINDOW:4:20 MINLEN:100

```
---

### Step 3 – Mapping

**Purpose:** the pipeline maps the reads to the reference genome
**Tools:** 'BWA'
**Inputs:** count matrix
**Outputs:** Normalized expression values (CPM), Log2 fold-changes (manual + statistical), differential expression test results ('fit2')
**Command:**
```bash
bwa mem -t 16 Reference.fna PGRG5_R1.trim.fq.1 PGRG5_R2.trim.fq.1 > Mapped.sam

```
### Step 4 - BAM TO SAM AND SORTING

**Purpose:** This part of the workflow converts the .sam file to .bam file the sorts it and index the bam file
**Tools:** 'Samtools'
**Inputs:** .sam file
**Outputs:** .bam file, .bam.bai file
**Command:**

```bash
samtools view -b Mapped.sam > Mapped.bam
samtools sort -@ 4 -o Mapped.sorted.bam Mapped.bam
samtools index Mapped.sorted.bam


```
---
### Step 5 - Generate Consensus

**Purpose:** This part of the workflow takes the mapped sorted bam file and generate a gap consensus genome
**Tools:** 'samtools'
**Inputs:** bam file
**Outputs:** .fa file
**Command:**

```bash
samtools consensus -f fasta -o consensus.fa Mapped.sorted.bam

```
---

### Step 6 - Variant Calling

**Purpose:** This part of the workflow uses bcftools to identify SNPs and Indels from the sorted bam file of the mapping, index the generated vcf file with snps then filter the snps.The variants 
are then annotated using bedtools
**Tools:** 'bcftools', 'bedtools'
**Inputs:** sorted bam file
**Outputs:** .vcf.gz file
**Command:**

```bash
REFERENCE="Reference.fna"
BAM="Mapped.sorted.bam"
#variant calling
bcftools mpileup -f $REFERENCE $BAM | bcftools call --ploidy 1 -mv -Oz -o variants.vcf.gz 

bcftools index variants.vcf.gz

bcftools filter -i 'AF>0.25' variants.vcf.gz -Oz -o filtered_variants.vcf.gz
#Variant annotation
bcftools query -f '%CHROM\t%POS0\t%POS\t%ID\n' filtered_variants.vcf.gz > variants.bed
bedtools intersect -a variants.bed -b features.bed -wa -wb > annotated_variants.txt

```
---
### Step 7 - De-novo assembly

**Purpose:** This part of the workflow makes a de novo assembly using spaded and then prokka is used for contig annotation
**Tools:** 'Spades', 'Prokka'
**Inputs:** .fq file
**Outputs:** .fasta
**Command:**

```bash
spades.py -1 PGRG5_R1.fq -2 PGRG5_R2.fq --isolate -o spades_output -t 4

prokka spades_output/contigs.fasta --outdir prokka_output --prefix PGRG5


```
---
