> Archived, superseded instructions. Use [current quick start](../../quick-start.md).

# New-run quick start

From this repository:

```bash
python3 scripts/new_run.py 20260911_yourname
```

Edit the generated `../chip_runs/20260911_yourname/pipeline.env` and `samples_master.csv`. Supply absolute paired FASTQ, reference FASTA/GTF and optional sheet paths. Include matching Input samples and appropriate biological replicate metadata. Keep `RESET_OUTPUTS=false`. The generator refuses to overwrite an existing directory.

The simple template runs QC through MACS3, bigWig and summaries. Use pipeline.advanced.env.example when you need individual module switches.

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

## Standard and advanced configuration

`pipeline.env.example` is a self-contained HPC configuration for the MH-style mouse paired-end workflow. It runs QC, alignment, filtering, independent MACS3 calls at q=0.05 and q=0.01, bigWig, MultiQC and delivery. It does not merge samples or run IDR, consensus, DiffBind, FRiP, annotation or motifs. The reference is GRCm39 / GENCODE vM27; shared liver Input 25L007941 is fixed. This preset is only appropriate when that reference, control and narrow-peak analysis match the experiment.

`new_run.py` creates the env, three CSV templates, Input mount config and submission script. Replace example samples in all three CSVs, keeping sample IDs consistent. The master contains only new ChIP FASTQs; the MACS3 sheet selects the existing control BAM, and the manifest supplies the control QC root. Their paths are fixed in the generated files, not inferred from comments in the env. Shared Input data must be available at the configured HPC path.

Results include `macs3_output/consensus_q0.05/` and `macs3_output/strict_q0.01/`. Here “consensus” is only the MACS3 branch name, not a replicate merge. Keep `RUN_PEAK_CONSENSUS=false`.

For other workflows use `pipeline.advanced.env.example` and review its switches. Do not change a running job's configuration. Local execution requires local references/Input and container settings; the supplied preset is for HPC.
