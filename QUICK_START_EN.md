# Nextflow ChIP-seq Pipeline Quick Start

This guide is for first-time users. It explains what files you need, which tables to fill in, which configuration values to edit, and how to launch the pipeline.

For the full user manual, see:

```text
MANUAL_EN.md
```

## 1. What This Pipeline Does

Default workflow:

```text
FastQC
  -> fastp trimming
  -> BWA alignment
  -> Picard BAM processing/QC
  -> MAPQ filtering
  -> MACS3 peak calling
  -> IDR / consensus peaks
  -> FRiP / BigWig / annotation / motif / heatmap / DiffBind
  -> MultiQC
  -> result delivery
```

The core inputs are paired-end FASTQ files, a reference genome FASTA, a GTF annotation file, and a sample metadata table called `samples_master.csv`.

## 2. Files You Need Before Running

### Required

1. Paired-end FASTQ files

```text
sample_R1.fastq.gz
sample_R2.fastq.gz
```

2. Reference genome FASTA

```text
/path/to/genome.fa
```

3. GTF annotation

```text
/path/to/annotation.gtf
```

4. Main sample table

```text
samples_master.csv
```

5. Pipeline configuration file

```text
pipeline.env
```

### Required on HPC

- Nextflow
- Slurm
- Singularity
- Container `.sif` files referenced by each module's `configs/slurm.config`
- BWA index built for the selected `REFERENCE_FASTA`

If any of these are uncertain, test the pipeline on the target HPC before claiming it is ready for production use.

## 3. Copy the Configuration File

Go to the launcher folder:

```bash
cd /path/to/pipelines/nextflow-chipseq
cp pipeline.env.example pipeline.env
```

Edit it:

```bash
nano pipeline.env
```

## 4. Edit `pipeline.env`

Set these values first:

```bash
PROFILE=hpc
HPC_MAIL_USER=molendo.hpc@gmail.com
PIPELINES_ROOT=/path/to/pipelines
OUTPUT_PROJECT_ROOT=/path/to/project_runs
SAMPLES_MASTER=/path/to/pipelines/nextflow-chipseq/samples_master.csv
REFERENCE_FASTA=/path/to/genome.fa
GTF=/path/to/annotation.gtf
```

| Field | Required | Meaning |
| --- | --- | --- |
| `PROFILE` | yes | Use `hpc` for Slurm/Singularity; use `local` for local Docker testing |
| `HPC_MAIL_USER` | yes | Email address for Slurm completion/failure notifications |
| `PIPELINES_ROOT` | yes | Parent directory containing all `nf-*` module folders |
| `OUTPUT_PROJECT_ROOT` | yes | Project-level output directory |
| `RUN_ID` | no | Leave empty for an automatic timestamp, or set a custom run name |
| `SAMPLES_MASTER` | yes | Path to the main sample metadata table |
| `REFERENCE_FASTA` | yes | Reference genome used for BWA alignment |
| `GTF` | yes | Annotation file used by ChIPseeker/enrichment |
| `RESUME` | no | Recommended: `true` |
| `START_FROM` | no | Start from a specific module, for example `picard` |

Recommended defaults for a first run:

```bash
RESUME=true
RESET_OUTPUTS=false
START_FROM=
```

## 5. Fill In `samples_master.csv`

Start from the template:

```bash
cp samples_master_template.csv samples_master.csv
```

Edit it:

```bash
nano samples_master.csv
```

The header must be:

```csv
sample_id,condition,replicate,library_type,fastq_r1,fastq_r2,is_control,control_id,use_for_idr,use_for_diffbind,enabled
```

### Column Guide

| Column | What to enter |
| --- | --- |
| `sample_id` | Unique sample name, for example `WT_rep1` |
| `condition` | Biological group, for example `WT`, `KO`, `treated`, `control` |
| `replicate` | Biological replicate number, for example `1`, `2`, `3` |
| `library_type` | Use `chip` for ChIP/IP samples; use `input` for input/control samples |
| `fastq_r1` | Absolute path to R1 FASTQ |
| `fastq_r2` | Absolute path to R2 FASTQ |
| `is_control` | `true` for input/control rows; `false` for ChIP rows |
| `control_id` | For ChIP rows, enter the matching input/control `sample_id`; leave empty for input rows |
| `use_for_idr` | `true` for ChIP replicates used by IDR; `false` for input rows |
| `use_for_diffbind` | `true` for ChIP replicates used by DiffBind; `false` for input rows |
| `enabled` | `true` to run the sample; `false` to temporarily exclude it |

### Common Example: Two Conditions, Two ChIP Replicates Each, One Shared Input

```csv
sample_id,condition,replicate,library_type,fastq_r1,fastq_r2,is_control,control_id,use_for_idr,use_for_diffbind,enabled
WT_rep1,WT,1,chip,/data/WT_rep1_R1.fastq.gz,/data/WT_rep1_R2.fastq.gz,false,Input_1,true,true,true
WT_rep2,WT,2,chip,/data/WT_rep2_R1.fastq.gz,/data/WT_rep2_R2.fastq.gz,false,Input_1,true,true,true
KO_rep1,KO,1,chip,/data/KO_rep1_R1.fastq.gz,/data/KO_rep1_R2.fastq.gz,false,Input_1,true,true,true
KO_rep2,KO,2,chip,/data/KO_rep2_R1.fastq.gz,/data/KO_rep2_R2.fastq.gz,false,Input_1,true,true,true
Input_1,Input,1,input,/data/Input_1_R1.fastq.gz,/data/Input_1_R2.fastq.gz,true,,false,false,true
```

## 6. If the Input/Control BAM Already Exists

If the input/control is already available as a processed BAM and should not be rerun from FASTQ, use an additional MACS3 samplesheet.

In `pipeline.env`:

```bash
MACS3_SAMPLESHEET=/path/to/macs3_samplesheet.csv
```

CSV format:

```csv
sample_id,treatment_bam,control_bam
WT_rep1,,/path/to/existing_input.nomulti.bam
WT_rep2,,/path/to/existing_input.nomulti.bam
```

Leaving `treatment_bam` empty means the pipeline will find the treatment BAM from the current `chipfilter_output`. The `control_bam` column points to the existing input/control BAM.

## 7. Choose Optional Analyses

Most downstream modules are enabled by default:

```bash
RUN_IDR=true
RUN_PEAK_CONSENSUS=true
RUN_DIFFBIND=true
RUN_BAMCOVERAGE=true
RUN_FRIP=true
RUN_CHIPSEEKER=true
RUN_HOMER=true
RUN_DEEPTOOLS_HEATMAP=true
RUN_MULTIQC=true
RUN_RESULT_DELIVERY=true
```

If there are no biological replicates, consider disabling:

```bash
RUN_IDR=false
RUN_DIFFBIND=false
RUN_DEEPTOOLS_HEATMAP=false
```

If you only need core peak calling, keep:

```bash
RUN_FASTQC=true
RUN_FASTP=true
RUN_BWA=true
RUN_PICARD=true
RUN_CHIPFILTER=true
RUN_MACS3=true
RUN_MULTIQC=true
RUN_RESULT_DELIVERY=true
```

Set other downstream modules to `false`.

## 8. Run the Pipeline

Sequential run:

```bash
bash run_end2end.sh pipeline.env
```

Safe parallel run:

```bash
bash run_end2end_parallel_safe.sh pipeline.env
```

For a first delivery test, use the sequential launcher because errors are easier to follow.

## 9. Resume After Failure

Keep:

```bash
RESUME=true
```

To restart from a specific module:

```bash
START_FROM=picard
```

Allowed values:

```text
fastqc
fastp
bwa
picard
chipfilter
macs3
idr
peak_consensus
diffbind
bamcoverage
frip
chipseeker
homer
deeptools
multiqc
result_delivery
```

Then rerun:

```bash
bash run_end2end.sh pipeline.env
```

## 10. Output Location

The run output is written under:

```bash
${OUTPUT_PROJECT_ROOT}/${RUN_ID}/
```

Typical folders:

```text
fastqc_output/
fastp_output/
bwa_output/
picard_output/
chipfilter_output/
macs3_output/
idr_output/
peak_consensus_output/
diffbind_output/
bamcoverage_output/
frip_output/
chipseeker_output/
homer_output/
deeptools_heatmap_output/
multiqc_output/
result_delivery_output/
```

For delivery, start with:

```text
result_delivery_output/
multiqc_output/
macs3_output/
idr_output/
peak_consensus_output/
diffbind_output/
bamcoverage_output/
chipseeker_output/
```

## 11. Final Pre-run Checklist

Before starting:

- All paths in `pipeline.env` exist.
- All FASTQ paths in `samples_master.csv` exist.
- `sample_id` values are unique.
- Every `control_id` matches an input/control `sample_id`.
- Boolean values use `true` / `false`.
- The BWA index exists for `REFERENCE_FASTA`.
- Singularity container paths exist on the HPC.

If any item is uncertain, run a small test before launching a full project.
