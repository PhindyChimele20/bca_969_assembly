#load modules
module load chpc/BIOMODULES
module load fastqc/0.12.1
module load trimmomatic/0.39
module load SOAPdenovo2/2.04
module load spades/3.15.5
module load quast/5.2.0

# ===============================
# Input data
READS_PE1="SRR25722949_1.fastq.gz"
READS_PE2="SRR25722949_2.fastq.gz"
OUTDIR="$PBS_O_WORKDIR/genome_assembly_pipeline"
THREADS=16

mkdir -p $OUTDIR
cd $OUTDIR

# Step 1: Raw Quality Check (FastQC)
echo ">>> Running FastQC on raw reads..."
mkdir -p fastqc_raw
fastqc -t $THREADS $PBS_O_WORKDIR/$READS_PE1 $PBS_O_WORKDIR/$READS_PE2 -o fastqc_raw

# ===============================
# Step 2: Read Cleaning with Trimmomatic
# ===============================
echo ">>> Running Trimmomatic..."
TRIM_JAR=/apps/chpc/bio/trimmomatic/0.39/trimmomatic-0.39.jar

java -jar $TRIM_JAR PE -threads $THREADS \
   $PBS_O_WORKDIR/$READS_PE1 $PBS_O_WORKDIR/$READS_PE2 \
   trimmed_R1_paired.fq.gz trimmed_R1_unpaired.fq.gz \
   trimmed_R2_paired.fq.gz trimmed_R2_unpaired.fq.gz \
   ILLUMINACLIP:/apps/chpc/bio/trimmomatic/0.39/adapters/TruSeq3-PE.fa:2:30:10 \
   SLIDINGWINDOW:4:20 MINLEN:50

# ===============================
# Step 3: Post-trimming Quality Check (FastQC)
# ===============================
echo ">>> Running FastQC on trimmed reads..."
mkdir -p fastqc_trimmed
fastqc -t $THREADS trimmed_R1_paired.fq.gz trimmed_R2_paired.fq.gz -o fastqc_trimmed

# ===============================
# Step 4: Assembly with SOAPdenovo
# ===============================
if [ ! -f $PBS_O_WORKDIR/config_file.txt ]; then
  echo "ERROR: config_file.txt not found in $PBS_O_WORKDIR"
  exit 1
fi

echo ">>> Running SOAPdenovo..."
SOAPdenovo-127mer all -s $PBS_O_WORKDIR/config_file.txt -K 63 -R -o soapdenovo_out -p $THREADS

# ===============================
# Step 5: Assembly with SPAdes
# ===============================
echo ">>> Running SPAdes..."
spades.py -1 trimmed_R1_paired.fq.gz -2 trimmed_R2_paired.fq.gz \
   -o spades_out -t $THREADS -m 60

# ===============================
# Step 6: Assess assemblies with QUAST
# ===============================
if [ -f spades_out/scaffolds.fasta ]; then
    echo ">>> Running QUAST..."
    quast.py soapdenovo_out.scafSeq spades_out/scaffolds.fasta -o quast_out -t $THREADS
else
    echo "WARNING: SPAdes output not found, skipping QUAST"
fi

# ===============================
# Step 7: Filter contigs <500 bp
# ===============================
if [ -f spades_out/scaffolds.fasta ]; then
    echo ">>> Filtering contigs <500bp..."
    awk '/^>/ {if (seqlen>=500) print seqname"\n"seq; seq=""; seqlen=0; seqname=$0}
         /^[^>]/ {seqlen+=length($0); seq=seq$0}
         END {if (seqlen>=500) print seqname"\n"seq}' spades_out/scaffolds.fasta > filtered_contigs.fasta
else
    echo "WARNING: No SPAdes scaffolds to filter"
fi

echo ">>> Pipeline finished at $(date)"
