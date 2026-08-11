# Nextflow ChIP-seq Pipeline User Manual

This manual is for users who want to run the `nextflow-chipseq` launcher, especially users who are not familiar with Nextflow but need to process ChIP-seq data from FASTQ files to peak calling, QC, annotation, visualization, and final delivery outputs.

This document describes the current pipeline design and intended usage. It does not claim that the pipeline has been fully tested on your target HPC. Before production delivery, run a small test and then a full validation run on the target environment.

## 1. Pipeline Overview

`nextflow-chipseq` is a launcher. It does not perform all analyses directly; instead, it calls separate `nf-*` modules in a controlled order.

Default module order:

```text
1. nf-fastqc
2. nf-fastp
3. nf-bwa
4. nf-picard
5. nf-chipfilter
6. nf-macs3
7. nf-idr
8. nf-peak-consensus
9. nf-diffbind
10. nf-bamcoverage
11. nf-frip
12. nf-chipseeker
13. nf-homer
14. nf-deeptools-heatmap
15. nf-multiqc
16. nf-result-delivery
```

Conceptually:

```text
FASTQ
  -> raw QC
  -> read trimming
  -> alignment
  -> sorted/deduplicated BAM
  -> filtered BAM
  -> peak calling
  -> reproducible/consensus peaks
  -> downstream QC and biological interpretation
  -> summary report and delivery folder
```

## 2. Required and Optional Files

### 2.1 Required Files

| File | Purpose |
| --- | --- |
| FASTQ R1/R2 | Paired-end sequencing reads |
| `samples_master.csv` | Main sample metadata table |
| `pipeline.env` | Runtime configuration |
| Reference FASTA | Used for BWA alignment |
| BWA index | Must match the reference FASTA |
| GTF annotation | Used for ChIPseeker annotation and enrichment |

### 2.2 Optional Files

| File | When to use it |
| --- | --- |
| `macs3_samplesheet.csv` | Existing input/control BAMs, or manual treatment/control BAM selection |
| `idr_pairs.csv` | Manual IDR replicate peak pairing |
| `consensus_pairs.csv` | Manual consensus peak replicate pairing |
| `diffbind_samplesheet.csv` | Manual DiffBind input design |
| `frip_samplesheet.csv` | Manual BAM-to-peak mapping for FRiP |
| `motif_compare_sheet.csv` | HOMER motif comparison |
| Blacklist BED | Peak-level blacklist filtering after MACS3 |
| MultiQC config YAML | Custom MultiQC report settings |

Recommended first run: fill only `samples_master.csv` and `pipeline.env`. Leave optional sheets empty unless you have a specific reason to override the automatic mode.

## 3. Recommended Directory Layout

Recommended layout:

```text
/path/to/pipelines/
  nextflow-chipseq/
    run_end2end.sh
    run_end2end_parallel_safe.sh
    pipeline.env.example
    pipeline.env
    samples_master.csv
    QUICK_START_EN.md
    MANUAL_EN.md
  nf-fastqc/
  nf-fastp/
  nf-bwa/
  nf-picard/
  nf-chipfilter/
  nf-macs3/
  nf-idr/
  nf-peak-consensus/
  nf-diffbind/
  nf-bamcoverage/
  nf-frip/
  nf-chipseeker/
  nf-homer/
  nf-deeptools-heatmap/
  nf-multiqc/
  nf-result-delivery/
```

`PIPELINES_ROOT` should point to:

```text
/path/to/pipelines
```

It should not point to:

```text
/path/to/pipelines/nextflow-chipseq
```

## 4. Runtime Configuration: `pipeline.env`

Copy the template:

```bash
cd /path/to/pipelines/nextflow-chipseq
cp pipeline.env.example pipeline.env
```

Edit it:

```bash
nano pipeline.env
```

### 4.1 Basic Settings

```bash
PROFILE=hpc
HPC_MAIL_USER=molendo.hpc@gmail.com
RESUME=true
PIPELINES_ROOT=/path/to/pipelines
OUTPUT_PROJECT_ROOT=/path/to/project_runs
RUN_ID=
RESET_OUTPUTS=false
START_FROM=
```

| Parameter | Meaning | Recommended |
| --- | --- | --- |
| `PROFILE` | Runtime profile. Use `hpc` for Slurm/Singularity or `local` for Docker | `hpc` |
| `HPC_MAIL_USER` | Slurm email notification address | `molendo.hpc@gmail.com` |
| `RESUME` | Enable Nextflow resume | `true` |
| `PIPELINES_ROOT` | Parent folder containing all module repositories | required |
| `OUTPUT_PROJECT_ROOT` | Project-level output destination | required |
| `RUN_ID` | Run name; leave empty for timestamp | optional |
| `RESET_OUTPUTS` | Archive existing output folders before rerun | usually `false` |
| `START_FROM` | Start from a specific module | empty for first run |

### 4.2 Sample Table and Reference Files

```bash
SAMPLES_MASTER=${PIPELINES_ROOT}/nextflow-chipseq/samples_master.csv

REFERENCE_FASTA=/path/to/genome.fa
GTF=/path/to/annotation.gtf
```

`REFERENCE_FASTA` must match the BWA index. `GTF` is used by annotation modules.

### 4.3 Core Thresholds

```bash
MAPQ_THRESHOLD=24
MACS3_QVALUE_IDR=0.1
MACS3_QVALUE_CONSENSUS=0.05
MACS3_QVALUE_STRICT=0.01
MACS3_PEAK_BLACKLIST_BED=
```

| Parameter | Purpose |
| --- | --- |
| `MAPQ_THRESHOLD` | Mapping quality threshold for BAM filtering |
| `MACS3_QVALUE_IDR` | More permissive MACS3 cutoff for the IDR branch |
| `MACS3_QVALUE_CONSENSUS` | MACS3 cutoff for consensus peaks |
| `MACS3_QVALUE_STRICT` | Strict MACS3 cutoff, commonly used for consensus/DiffBind |
| `MACS3_PEAK_BLACKLIST_BED` | Optional blacklist BED; leave empty to disable |

### 4.4 Optional Sheets

```bash
MACS3_SAMPLESHEET=
IDR_PAIRS_CSV=
DIFFBIND_SAMPLESHEET=
FRIP_SAMPLESHEET=
HOMER_MOTIF_COMPARE_SHEET=
CONSENSUS_PAIRS_CSV=
```

For a first run, leave these empty. The launcher will use `samples_master.csv` to drive downstream modules where possible.

### 4.5 Module Toggles

```bash
RUN_FASTQC=true
RUN_FASTP=true
RUN_BWA=true
RUN_PICARD=true
RUN_CHIPFILTER=true
RUN_MACS3=true
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

Guidance:

- If biological replicates are available, keep `RUN_IDR=true` and `RUN_DIFFBIND=true`.
- If there are no replicates, set `RUN_IDR=false`, `RUN_DIFFBIND=false`, and `RUN_DEEPTOOLS_HEATMAP=false`.
- If only BAMs and MACS3 peaks are needed, keep the workflow through `RUN_MACS3=true` and disable most downstream modules.
- For final delivery, keep `RUN_MULTIQC=true` and `RUN_RESULT_DELIVERY=true`.

## 5. Main Sample Table: `samples_master.csv`

`samples_master.csv` is the main metadata table. It tells the pipeline:

- Which FASTQ files belong to which sample.
- Which samples are ChIP/IP and which samples are input/control.
- Which input/control sample should be used for each ChIP sample.
- Which samples should be used for IDR and DiffBind.
- Which rows are enabled or disabled.

### 5.1 Required Header

Use this exact header:

```csv
sample_id,condition,replicate,library_type,fastq_r1,fastq_r2,is_control,control_id,use_for_idr,use_for_diffbind,enabled
```

### 5.2 Column Definitions

| Column | Required | Example | Meaning |
| --- | --- | --- | --- |
| `sample_id` | yes | `WT_rep1` | Unique sample ID |
| `condition` | yes | `WT` | Biological group |
| `replicate` | yes | `1` | Biological replicate number |
| `library_type` | yes | `chip` or `input` | Library role |
| `fastq_r1` | yes | `/data/a_R1.fastq.gz` | Absolute path to R1 FASTQ |
| `fastq_r2` | yes | `/data/a_R2.fastq.gz` | Absolute path to R2 FASTQ |
| `is_control` | yes | `true` / `false` | Whether this row is an input/control |
| `control_id` | recommended for ChIP rows | `Input_1` | Matching input/control `sample_id` |
| `use_for_idr` | yes | `true` / `false` | Include sample in IDR auto-pairing |
| `use_for_diffbind` | yes | `true` / `false` | Include sample in DiffBind auto mode |
| `enabled` | yes | `true` / `false` | Include or temporarily exclude the row |

### 5.3 ChIP Rows

Example ChIP row:

```csv
WT_rep1,WT,1,chip,/data/WT_rep1_R1.fastq.gz,/data/WT_rep1_R2.fastq.gz,false,Input_1,true,true,true
```

Rules:

- `library_type=chip`
- `is_control=false`
- `control_id` should match an input/control `sample_id`
- `use_for_idr=true` if the replicate should be used for IDR
- `use_for_diffbind=true` if the sample should be used for DiffBind

### 5.4 Input/Control Rows

Example input/control row:

```csv
Input_1,Input,1,input,/data/Input_1_R1.fastq.gz,/data/Input_1_R2.fastq.gz,true,,false,false,true
```

Rules:

- `library_type=input`
- `is_control=true`
- `control_id` should be empty
- `use_for_idr=false`
- `use_for_diffbind=false`

### 5.5 Complete Example

```csv
sample_id,condition,replicate,library_type,fastq_r1,fastq_r2,is_control,control_id,use_for_idr,use_for_diffbind,enabled
WT_rep1,WT,1,chip,/data/WT_rep1_R1.fastq.gz,/data/WT_rep1_R2.fastq.gz,false,Input_1,true,true,true
WT_rep2,WT,2,chip,/data/WT_rep2_R1.fastq.gz,/data/WT_rep2_R2.fastq.gz,false,Input_1,true,true,true
KO_rep1,KO,1,chip,/data/KO_rep1_R1.fastq.gz,/data/KO_rep1_R2.fastq.gz,false,Input_1,true,true,true
KO_rep2,KO,2,chip,/data/KO_rep2_R1.fastq.gz,/data/KO_rep2_R2.fastq.gz,false,Input_1,true,true,true
Input_1,Input,1,input,/data/Input_1_R1.fastq.gz,/data/Input_1_R2.fastq.gz,true,,false,false,true
```

## 6. Treatment and Input/Control Handling

MACS3 peak calling is based on:

```text
macs3 callpeak -t treatment.bam -c control.bam
```

In this pipeline:

- Treatment BAMs are ChIP/IP `*.nomulti.bam` files produced by `nf-chipfilter`.
- Control BAMs are input/control BAMs, ideally processed with the same reference and filtering strategy.

### 6.1 Input/Control Runs From FASTQ

This is the standard mode. Add the input/control sample as a row in `samples_master.csv`.

ChIP row:

```csv
WT_rep1,WT,1,chip,/data/WT_rep1_R1.fastq.gz,/data/WT_rep1_R2.fastq.gz,false,Input_1,true,true,true
```

Input/control row:

```csv
Input_1,Input,1,input,/data/Input_1_R1.fastq.gz,/data/Input_1_R2.fastq.gz,true,,false,false,true
```

The launcher processes both ChIP and input/control FASTQs through the upstream modules, then MACS3 resolves the matching control BAM automatically.

### 6.2 Input/Control BAM Already Exists

If the input/control BAM already exists and should not be rerun from FASTQ, provide a MACS3 samplesheet.

In `pipeline.env`:

```bash
MACS3_SAMPLESHEET=/path/to/macs3_samplesheet.csv
```

CSV:

```csv
sample_id,treatment_bam,control_bam
WT_rep1,,/path/to/existing_input.nomulti.bam
WT_rep2,,/path/to/existing_input.nomulti.bam
KO_rep1,,/path/to/existing_input.nomulti.bam
KO_rep2,,/path/to/existing_input.nomulti.bam
```

If `treatment_bam` is empty, the module finds it from the current run's `chipfilter_output` using:

```text
<sample_id>*.nomulti.bam
```

Important compatibility checks:

- Same genome build
- Same chromosome naming style, for example `chr1` vs `1`
- Sorted and readable BAM
- Preferably indexed with `.bai`

## 7. Optional Sheets

### 7.1 `IDR_PAIRS_CSV`

By default, IDR pairs replicates automatically from `samples_master.csv` using `condition` and `replicate`.

Use `IDR_PAIRS_CSV` if you want manual control:

```bash
IDR_PAIRS_CSV=/path/to/idr_pairs.csv
```

Format:

```csv
pair_name,rep1_peaks,rep2_peaks
WT,/path/to/WT_rep1_peaks.narrowPeak,/path/to/WT_rep2_peaks.narrowPeak
KO,/path/to/KO_rep1_peaks.narrowPeak,/path/to/KO_rep2_peaks.narrowPeak
```

### 7.2 `CONSENSUS_PAIRS_CSV`

Use this if you do not want automatic consensus peak pairing:

```bash
CONSENSUS_PAIRS_CSV=/path/to/consensus_pairs.csv
```

Check the `nf-peak-consensus` README for the exact current columns.

### 7.3 `DIFFBIND_SAMPLESHEET`

Use this for full manual control of DiffBind input:

```bash
DIFFBIND_SAMPLESHEET=/path/to/diffbind_samplesheet.csv
```

Common columns:

```csv
SampleID,Condition,Replicate,bamReads,Peaks,PeakCaller
```

Automatic mode is easier for first-time users. Manual DiffBind sheets are useful for complex designs.

### 7.4 `FRIP_SAMPLESHEET`

Use this if you want to manually assign each BAM to a peak file for FRiP:

```bash
FRIP_SAMPLESHEET=/path/to/frip_samplesheet.csv
```

Format:

```csv
sample_id,bam,peaks
WT_rep1,/path/to/WT_rep1.nomulti.bam,/path/to/WT_idr.sorted.narrowPeak
```

### 7.5 `HOMER_MOTIF_COMPARE_SHEET`

Use this for HOMER motif comparison:

```bash
HOMER_MOTIF_COMPARE_SHEET=/path/to/motif_compare_sheet.csv
```

Format:

```csv
group_name,target_bed,background_bed
KO_unique_vs_WT_bg,/path/to/target.bed,/path/to/background.bed
```

## 8. Peak Sources

Downstream modules can use different peak sources:

```bash
FRIP_PEAK_SOURCES=
CHIPSEEKER_PEAK_SOURCES=
HOMER_PEAK_SOURCES=
```

If left empty, the launcher selects sources based on enabled upstream modules.

Common values:

```text
idr
consensus_q0.01
consensus_q0.05
diffbind
```

Example:

```bash
FRIP_PEAK_SOURCES=idr,consensus_q0.01,consensus_q0.05
CHIPSEEKER_PEAK_SOURCES=idr,consensus_q0.01,consensus_q0.05,diffbind
HOMER_PEAK_SOURCES=idr,consensus_q0.01
```

Do not select a peak source if the corresponding upstream module was disabled.

## 9. Running the Pipeline

### 9.1 Sequential Launcher

```bash
cd /path/to/pipelines/nextflow-chipseq
bash run_end2end.sh pipeline.env
```

Use this for the first test because logs are easier to interpret.

### 9.2 Safe Parallel Launcher

```bash
bash run_end2end_parallel_safe.sh pipeline.env
```

Use this after the environment and inputs have already been validated.

## 10. Resuming or Starting From a Module

Recommended:

```bash
RESUME=true
```

To start from a module:

```bash
START_FROM=macs3
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

`START_FROM` does not create upstream outputs. For example, starting from `macs3` requires an existing `chipfilter_output`.

## 11. Output Structure

The run output is written to:

```bash
${OUTPUT_PROJECT_ROOT}/${RUN_ID}/
```

If `RUN_ID` is empty, the launcher creates a timestamp-based run ID.

Typical output folders:

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
logs/
```

### 11.1 Delivery Priorities

| Folder | Contents |
| --- | --- |
| `result_delivery_output/` | Curated delivery outputs |
| `multiqc_output/` | Combined QC report |
| `chipfilter_output/` | Final filtered BAM/BAI/QC files |
| `macs3_output/` | Per-sample peak calls |
| `idr_output/` | IDR reproducible peaks |
| `peak_consensus_output/` | Consensus peaks |
| `diffbind_output/` | Differential binding results |
| `bamcoverage_output/` | BigWig tracks |
| `chipseeker_output/` | Peak annotation |
| `homer_output/` | Motif analysis |

The pipeline is designed to preserve final BAM/BAI/QC files and downstream results, not large SAM intermediates.

## 12. Common Run Scenarios

### 12.1 Standard Replicated ChIP-seq

Two or more conditions, at least two ChIP replicates per condition, and one or more input/control samples.

Recommended:

```bash
RUN_IDR=true
RUN_PEAK_CONSENSUS=true
RUN_DIFFBIND=true
RUN_FRIP=true
RUN_CHIPSEEKER=true
RUN_MULTIQC=true
RUN_RESULT_DELIVERY=true
```

### 12.2 No Biological Replicates

Recommended:

```bash
RUN_IDR=false
RUN_DIFFBIND=false
RUN_DEEPTOOLS_HEATMAP=false
```

Keep:

```bash
RUN_MACS3=true
RUN_BAMCOVERAGE=true
RUN_CHIPSEEKER=true
RUN_MULTIQC=true
RUN_RESULT_DELIVERY=true
```

### 12.3 Existing Input/Control BAM

Use:

```bash
MACS3_SAMPLESHEET=/path/to/macs3_samplesheet.csv
```

Do not add a nonexistent input FASTQ row to `samples_master.csv` just to represent an existing BAM.

### 12.4 Peak Calling Only

Disable downstream modules:

```bash
RUN_IDR=false
RUN_PEAK_CONSENSUS=false
RUN_DIFFBIND=false
RUN_BAMCOVERAGE=false
RUN_FRIP=false
RUN_CHIPSEEKER=false
RUN_HOMER=false
RUN_DEEPTOOLS_HEATMAP=false
RUN_MULTIQC=true
RUN_RESULT_DELIVERY=true
```

## 13. Pre-run Checklist

### File Checks

- `pipeline.env` exists.
- `samples_master.csv` exists.
- All FASTQ paths exist.
- `REFERENCE_FASTA` exists.
- BWA index exists for the reference FASTA.
- `GTF` exists.
- Singularity container `.sif` files exist on the HPC.

### Table Checks

- `sample_id` values are unique.
- ChIP rows have valid `control_id` values.
- Input/control rows have `is_control=true`.
- ChIP rows have `is_control=false`.
- Boolean values use `true` / `false`.
- Replicate numbers are consistent within each condition.
- Excluded samples are marked with `enabled=false`.

### Experimental Design Checks

- IDR requires at least two biological replicates within a condition.
- DiffBind requires comparable conditions and replicates.
- Shared input/control BAMs must use the same genome build as treatment BAMs.
- Blacklist BED must match the genome build.

## 14. Common Problems

### 14.1 FASTQ Not Found

Check:

- Absolute paths in `samples_master.csv`.
- File name spelling.
- Whether the HPC can access the storage path.

### 14.2 MACS3 Cannot Find Control

Check:

- ChIP row `control_id` matches an input/control `sample_id`.
- Input/control row has `enabled=true`.
- Input/control produced a `*.nomulti.bam`.
- If using an existing BAM, `MACS3_SAMPLESHEET` is filled correctly.

### 14.3 IDR Has No Output

Check:

- Each condition has at least two ChIP replicates.
- `use_for_idr=true`.
- `RUN_IDR=true`.
- MACS3 produced peaks in the `idr_q0.1` branch.

### 14.4 DiffBind Has No Contrast

Possible reasons:

- Not enough replicates per group.
- Only one condition.
- `use_for_diffbind=false`.
- Inconsistent `condition` or `replicate` values.

### 14.5 ChIPseeker or HOMER Cannot Find Peaks

Check:

- `CHIPSEEKER_PEAK_SOURCES` or `HOMER_PEAK_SOURCES` does not point to disabled upstream results.
- `RUN_IDR`, `RUN_PEAK_CONSENSUS`, and `RUN_DIFFBIND` match the selected peak sources.

## 15. Delivery Recommendations

At minimum, keep:

```text
pipeline.env
samples_master.csv
multiqc_output/
result_delivery_output/
logs/
```

If storage allows, also keep:

```text
chipfilter_output/*.nomulti.bam
chipfilter_output/*.nomulti.bam.bai
macs3_output/
idr_output/
peak_consensus_output/
bamcoverage_output/
chipseeker_output/
diffbind_output/
```

Do not treat large SAM intermediates as primary delivery files. The intended deliverables are final BAM/BAI/QC files and downstream analysis results.

## 16. Notes for Maintainers

- Record architecture decisions in the `nextflow-chipseq` overview or manual.
- Each module should remain independently testable.
- Keep `main.nf`, `nextflow.config`, and profile config parameters consistent.
- Launcher argument names must match module interfaces.
- Archive one-off troubleshooting notes after the issue is solved.
- Do not write "pipeline tested successfully" unless a real run was completed on the target environment.

## 17. Minimal Command Summary

```bash
cd /path/to/pipelines/nextflow-chipseq
cp pipeline.env.example pipeline.env
cp samples_master_template.csv samples_master.csv

# edit pipeline.env and samples_master.csv

bash run_end2end.sh pipeline.env
```

If the run fails, fix the issue and rerun:

```bash
bash run_end2end.sh pipeline.env
```

To continue from a specific module:

```bash
# edit pipeline.env
START_FROM=macs3
RESUME=true

bash run_end2end.sh pipeline.env
```
