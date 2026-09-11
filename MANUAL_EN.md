# Operations and handoff

See [Quick Start](QUICK_START_EN.md), [layout and limitations](README.md), and [sample fields](docs/SAMPLES_MASTER_GUIDE.md).

Use one `chip_runs/YYYYMMDD_runner` directory per analysis. Results retain their familiar `*_output` names directly under that run. `02_run_record/<attempt>` retains config/sheet snapshots, source commit/hash/diff records, exact commands, per-module logs and status. `99_intermediate` contains stable module execution directories, Nextflow cache/history, task work, temporary files, container cache and a run-local BWA index (or links to a matching existing reference index). No reference index is built in the external reference directory by the launcher.

Both launchers call the absolute module main.nf from a run-local execution directory and set an explicit work directory. Native Nextflow project config discovery is preserved. Python 3.8+, Bash and Nextflow are required; Docker/Slurm/Singularity and compatible tools depend on the selected profile. NEXTFLOW_CONFIG permits an absolute custom resource/container config, with final path isolation applied by the launcher.

The run lock rejects concurrent launchers for the same ID. Different run IDs have independent caches/work. After a machine crash, verify that all launcher/compute tasks stopped before manually removing a stale lock. Each attempt has a distinct status record; previous failed logs are retained. COMPLETED covers enabled modules only. START_FROM requires existing upstream results.

Use the same ID/code/input and RESUME=true to recover. Changed data or analysis settings require a new ID, since modules may skip existing published files even with Nextflow resume disabled. RESET_OUTPUTS=true archives old result folders and can increase storage. Prefer false.

After inspecting and saving results and records, delete the whole 99_intermediate directory. Do not delete it during active or failed runs. This removes task cache/work and prevents cache-based resume. Copy-published result folders remain independent; their FASTQ/BAM outputs still take space. Original inputs, software installations, Nextflow framework cache and Docker images are not part of this cleanup.

OUTPUT_PROJECT_ROOT is retired: use CHIP_RUNS_ROOT, a directory literally named chip_runs outside code repos. Existing results and caches are not automatically migrated. Direct Nextflow execution from module repos bypasses this layout; use the provided launchers for handoff runs.

Keep MACS3 thresholds at 0.1/0.05/0.01 until downstream profile names are changed consistently. Consensus auto pairing requires exactly two ChIP replicates per condition; IDR selects the first two. Pooled samples are not biological replicates. Heatmaps currently depend on DiffBind. External shared control BAMs require explicit MACS3 pairing and suitable container mounts. Different species require genome-size/HOMER/annotation settings in addition to FASTA/GTF. Runtime validation does not establish biological validity.
