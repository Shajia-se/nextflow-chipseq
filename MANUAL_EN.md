# User manual — standard ChIP-seq workflow

## Scope and fixed settings

This manual describes the current local standard template. Follow [quick-start.md](quick-start.md) for commands and complete CSV examples. It is an HPC preset for mouse paired-end narrow-peak analysis with the processed liver Input 25L007941. It is not a general preset for other tissues, species, CUT&RUN or broad histone marks without review.

| Setting | Standard value |
|---|---|
| Reference | GRCm39 / GENCODE vM27 |
| FASTA | `/ictstr01/groups/idc/projects/uhlenhaut/jiang/reference/bwa/GRCm39_vM27/GRCm39.primary_assembly.genome.fa` |
| GTF | `/ictstr01/groups/idc/projects/uhlenhaut/jiang/reference/gtf/gencode.vM27.primary_assembly.annotation.gtf` |
| Shared Input root | `/ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/chip_runs/shared_input/liver/25L007941` |
| Control BAM | `chipfilter_output/25L007941.nomulti.bam` under that root |
| MAPQ threshold | 24 |
| MACS3 q-values | 0.05 and 0.01 |

Enabled: FastQC, fastp, BWA, Picard, chipfilter, MACS3, bamCoverage, MultiQC and result delivery. Disabled: IDR, peak consensus, DiffBind, FRiP, ChIPseeker, HOMER and heatmaps. MACS3 processes each sample independently at both thresholds. The default bigWig is coverage rather than Input-subtracted signal.

## Files and responsibilities

| File | What the user changes |
|---|---|
| `pipeline.env` | Run identity/email; keep preset paths and switches for this workflow |
| `samples_master.csv` | New sample IDs, conditions and absolute paired FASTQ paths |
| `macs3_samplesheet.csv` | Matching sample IDs; leave treatment_bam empty and retain shared control_bam |
| `shared_control_manifest.csv` | Matching sample IDs; retain control_id and control_root |
| `external_input.config` | Normally unchanged; mounts the shared control root |
| `submit.sh` | Check partition/qos; keep generated absolute run paths |

Generate these with `python3 scripts/new_run.py DATE_PERSON` from the launcher repository. Existing run names are rejected. The generator provides example rows, not an automatic discovery of your samples. Replace them in all three tables. No cross-table consistency check currently guarantees they match.

The MACS3 sheet selects the actual Input BAM. The manifest only records its identity and reads previous QC outputs for delivery. Environment comments do not configure the Input: CSV paths and mount config are authoritative. The Input is not reprocessed, and should not be included as a FASTQ row in the standard master sheet.

## Directory layout

```text
pipelines/
  nextflow-chipseq/             # launcher code, templates and these manuals
  nf-*/                        # tool repositories
  chip_runs/
    shared_input/liver/25L007941/  # reusable reference control; preserve
    DATE_PERSON/
      pipeline.env
      samples_master.csv
      macs3_samplesheet.csv
      shared_control_manifest.csv
      external_input.config
      submit.sh
      launcher.JOB_ID.log
      *_output/                # results of enabled modules
      02_run_record/<attempt>/ # snapshots, versions, commands, logs and status
      99_intermediate/         # execution/cache, work, tmp, BWA index, container cache
```

RUNNER is metadata; it does not create another folder level. CHIP_RUNS_ROOT must end in `chip_runs` and remain outside code repositories. Do not use the retired OUTPUT_PROJECT_ROOT. Do not move a generated run folder without updating its absolute paths. Direct module execution can bypass the layout; use submit.sh for ordinary users.

## Submit, monitor and recover

Use `sbatch submit.sh` from the run directory. It starts the parallel-safe launcher on a compute allocation; modules submit their own Slurm tasks. Multiple job IDs are expected. Use squeue, the launcher log and per-module console/status files as shown in the quick start. Each invocation has a separate record. COMPLETED describes enabled modules only and does not certify biological quality.

If a run fails, inspect the first failing module, correct the cause and resubmit the same script with unchanged input/code, RESUME=true and RESET_OUTPUTS=false. Retain 99_intermediate. Do not launch the same run concurrently. A stale lock may be removed only after checking that both controller and compute tasks have stopped.

New samples, reference changes or changed peak thresholds require a new run ID: some modules skip existing published files independently of Nextflow cache. Keep START_FROM empty unless required upstream results already exist. Avoid RESET_OUTPUTS=true for routine recovery.

## Outputs and cleanup

Inspect peaks at both thresholds, bigWigs and the MultiQC report. Check sample counts, mapping and duplication statistics, and missing/NA summary fields. The lean delivery contains summaries; archive desired module outputs separately. Missing disabled analyses are expected, not evidence those analyses passed.

After results and 02_run_record are checked and backed up, delete only this run's 99_intermediate if you no longer need cached resume. Published results are copied; intermediate cleanup does not remove their FASTQ/BAM files. Preserve raw data, references and shared_input. Docker images and the installed Nextflow framework are managed separately.

## Advanced use and validation

The old settings remain in `archive/configs/pipeline.advanced.env` locally; the reusable full template is `archive/configs/pipeline.advanced.env.example`. It enables all modules by default and needs design review. The standard env is self-contained and does not source hidden defaults. Local Docker use requires local data/control/reference paths and suitable container settings, not just changing PROFILE.

See [test scope](tests/README.md). Previous synthetic container tests and launcher tests do not establish that every revised preset has completed on HPC. The current standard configuration and generated files have been checked locally; confirm the real run's logs and outputs before declaring HPC acceptance.

Legacy tutorials are retained under docs for developer reference; [this manual](MANUAL_EN.md) and the quick start govern the current standard workflow.

Detailed tool settings, configured versions, output interpretation and launcher roles: [technical user manual](docs/USER_MANUAL_EN.md).
