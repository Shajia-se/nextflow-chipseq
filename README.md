# Modular ChIP-seq launcher

One run, one folder: **`chip_runs/YYYYMMDD_runner/`**. Code repositories stay separate from results, work files, caches and logs. Use either launcher; both use the same directory management.

## Create and run

```bash
python3 scripts/new_run.py 20260911_shan
```

This creates `../chip_runs/20260911_shan/pipeline.env`, `samples_master.csv`, and `submit.sh`. Edit the sample paths, reference, email and module switches before submitting:

```bash
sbatch ../chip_runs/20260911_shan/submit.sh
```

Or launch directly (the `hpc` profile still submits compute tasks to Slurm):

```bash
bash run_end2end_parallel_safe.sh /absolute/path/chip_runs/20260911_shan/pipeline.env
```

For sequential scheduling use `run_end2end.sh` with the same env. Local Docker runs require `PROFILE=local` and valid local container/resource settings; an absolute `NEXTFLOW_CONFIG` can override these settings. Requires Bash, Python 3.8+, Java/Nextflow and the chosen executor/container runtime.

## Files

```text
chip_runs/20260911_shan/
  pipeline.env
  samples_master.csv
  submit.sh
  fastqc_output/                 # module results; existing names retained
  fastp_output/
  bwa_output/
  ...
  02_run_record/<attempt>/       # env/sheets, code hashes/diffs, commands, logs, status
  99_intermediate/
    execution/nf-*/              # Nextflow launch directory, .nextflow cache/history
    work/nf-*/                   # task work directories
    tmp/nf-*/
    reference/bwa/               # run-local index, or links to an existing index
    container_cache/
  README_交付与清理.md
```

Default root is `${PIPELINES_ROOT}/chip_runs`. `CHIP_RUNS_ROOT` may point to a different storage volume, but its final directory must be named `chip_runs` and must be outside code repositories. `RUN_ID` is a single directory name. If omitted, it defaults to a timestamp plus `RUNNER`/username; use an explicit ID to resume reliably.

`OUTPUT_PROJECT_ROOT` is retired. Old values such as `runs/default_project`, `runs_output`, or project subdirectories are rejected before launching tools. Existing results/caches are not automatically migrated. The layout applies to these launchers; a direct `nextflow run` in a module repo bypasses it.

## Resume and clean

Use the same run ID, code and inputs with `RESUME=true`, `RESET_OUTPUTS=false`. Set `START_FROM` only when earlier required outputs exist. Each invocation has its own retained record; execution/work paths remain stable across attempts. A lock prevents concurrent launchers from using the same run; different run IDs are independent. Following an abnormal machine shutdown, verify that all launcher/compute jobs have stopped before manually removing a stale `.launcher.lock`.

After the latest attempt says `COMPLETED`, check and save the outputs and `02_run_record`. Then **delete the entire `99_intermediate` directory** if cache-based resume is no longer needed. Do not delete intermediate files while a run is active or failed. Results use copy publication and are independent of this directory. Some published outputs are large FASTQ/BAM files; this cleanup does not remove them. Framework installations, Java, and the Docker image store remain managed by their existing runtimes, not by per-run cleanup.

Changed inputs or thresholds require a new run ID: some modules skip already-published files independently of Nextflow caching. COMPLETED only describes enabled modules in that attempt, not every possible analysis branch.

## Analysis scope

Modules: FastQC → fastp → BWA → Picard → chipfilter → MACS3; then IDR/consensus/DiffBind/bamCoverage, downstream FRiP/ChIPseeker/HOMER/heatmaps, MultiQC and result delivery as enabled. Core modules can also be disabled. Replicate/control design must support the enabled branches; pooled samples do not replace biological replicates. Heatmaps currently require DiffBind. Consensus auto mode expects exactly two ChIP replicates per condition; IDR auto mode selects the first two.

Keep the default MACS3 thresholds 0.1 / 0.05 / 0.01 until downstream profile names are configured consistently. Other species require reviewing MACS3 genome size, bamCoverage effective genome size, HOMER genome and annotation settings, not only FASTA/GTF. Runtime layout changes do not validate biological inference.

- [中文快速开始](QUICK_START_CN.md)
- [English quick start](QUICK_START_EN.md)
- [中文操作手册](MANUAL_CN.md)
- [English manual](MANUAL_EN.md)
- [Samples master fields](docs/SAMPLES_MASTER_GUIDE.md)
- [Validation scope](tests/README.md)
