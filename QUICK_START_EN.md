# New-run quick start

From this repository:

```bash
python3 scripts/new_run.py 20260911_yourname
```

Edit the generated `../chip_runs/20260911_yourname/pipeline.env` and `samples_master.csv`. Supply absolute paired FASTQ, reference FASTA/GTF and optional sheet paths. Include matching Input samples and appropriate biological replicate metadata. Keep `RESET_OUTPUTS=false`. The generator refuses to overwrite an existing directory.

The template enables all branches; review switches before submission. For an upstream test enable FASTQC, FASTP, BWA, PICARD, CHIPFILTER and MULTIQC and disable other RUN_* switches. Enable downstream branches only for a supported experimental design.

Submit on HPC:

```bash
sbatch ../chip_runs/20260911_yourname/submit.sh
```

Or run the launcher directly:

```bash
bash run_end2end_parallel_safe.sh /absolute/path/chip_runs/20260911_yourname/pipeline.env
```

For local Docker use PROFILE=local and compatible resources/images. NEXTFLOW_CONFIG optionally supplies an absolute path to a site/local override config.

Results are the run's `*_output/` directories. `02_run_record/<attempt>/` contains settings, input sheets, code hashes/diffs and logs/status. After checking and saving completed results and records, delete the whole `99_intermediate/` directory. This removes Nextflow work/cache and disables cache-based resume. Keep it for active/failed runs.

Resume with the same RUN_ID, code, inputs and RESUME=true. New inputs/settings require a new ID because some modules also skip existing published files. Do not reuse old OUTPUT_PROJECT_ROOT paths: use CHIP_RUNS_ROOT (a directory named chip_runs outside code repos). No existing data is automatically relocated. Direct module execution bypasses launcher isolation.
