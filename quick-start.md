# Quick start — standard HPC workflow

Mouse paired-end samples, shared liver Input **25L007941**, independent MACS3 calls at **q=0.05 and q=0.01**, bigWig and QC summaries. No sample merging or replicate comparisons. Confirm this control and narrow-peak analysis match your experiment.

## 1. Create a run

```bash
cd /ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/nextflow-chipseq
python3 scripts/new_run.py 20260914_MH
cd ../chip_runs/20260914_MH
```

Replace the run name with a new date/person name. Do not move the generated folder: paths in the env and submit script are absolute.

## 2. Fill the three sample sheets

Delete all example rows. Use the same sample IDs in all three files. The generator creates templates only; later edits are not synchronized automatically.

`samples_master.csv` — new ChIP FASTQs only; do not add the processed shared Input:

```csv
sample_id,condition,replicate,library_type,fastq_r1,fastq_r2,is_control,control_id,use_for_idr,use_for_diffbind,enabled
sample_A,condition_A,1,chip,/absolute/path/sample_A_R1.fastq.gz,/absolute/path/sample_A_R2.fastq.gz,false,,false,false,true
```

`macs3_samplesheet.csv` — keep treatment_bam empty to select this run's filtered BAM:

```csv
sample_id,treatment_bam,control_bam
sample_A,,/ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/chip_runs/shared_input/liver/25L007941/chipfilter_output/25L007941.nomulti.bam
```

`shared_control_manifest.csv` — control_root is the parent of all shared Input result folders:

```csv
sample_id,control_id,control_root
sample_A,25L007941,/ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/chip_runs/shared_input/liver/25L007941
```

Repeat a row for every new sample in each table. Use absolute R1/R2 paths, unique IDs and lowercase true/false. Do not use spaces, commas or shell special characters in IDs/paths. For independent samples without biological replicates, use replicate=1 and appropriate condition labels.

## 3. Check the run settings

In `pipeline.env`, check email and RUNNER; preserve the generated RUN_ID and paths. Reference FASTA/GTF, shared Input and analysis switches are preset for this HPC workflow. Keep `RESUME=true`, `RESET_OUTPUTS=false` and `START_FROM=`. Keep the generated `external_input.config` so containers can read the Input BAM and QC files. Review partition/qos in `submit.sh`. Nextflow, Java, Python 3.8+ and Singularity must be available to the batch job.

## 4. Submit and monitor

From the run directory:

```bash
sbatch submit.sh
squeue -u "$USER"
```

Use the number printed by sbatch below (replace JOB_ID):

```bash
tail -f launcher.JOB_ID.log
sacct -j JOB_ID --format=JobID,JobName,State,ExitCode,Elapsed
```

Ctrl+C stops log viewing, not the job. Module logs are under `02_run_record/<attempt>/logs/`, including `nf-bwa.console.log`. A successful launcher ends with `[STATUS] COMPLETED`; also inspect the outputs. A submitted job is not proof of successful execution.

## 5. Collect and clean

- Peaks: `macs3_output/consensus_q0.05/` and `macs3_output/strict_q0.01/`.
- Tracks: `bamcoverage_output/` (ChIP coverage, not Input-subtracted).
- QC: `multiqc_output/`; delivery summaries: `result_delivery_output/`.
- Provenance and logs: `02_run_record/`.

“consensus_q0.05” is a MACS3 branch name; this workflow does not compute replicate consensus. The lean delivery is a summary package, not a replacement for saving peaks and bigWigs.

After successful completion, inspect and back up results plus records. Only then remove `99_intermediate/` if resume is no longer needed. Never clean an active run or the reusable `chip_runs/shared_input/` directory. Published FASTQ/BAM files still occupy space after intermediate cleanup.

See [English manual](MANUAL_EN.md), [中文手册](MANUAL_CN.md), or [advanced options](archive/configs/pipeline.advanced.env.example).

Detailed tool settings, configured versions, output interpretation and launcher roles: [technical user manual](docs/USER_MANUAL_EN.md).
