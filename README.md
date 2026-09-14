# ChIP-seq pipeline — standard HPC workflow

Mouse paired-end analysis with fixed GRCm39/vM27 references and shared liver Input 25L007941. Each sample produces MACS3 peaks at q=0.05 and q=0.01, bigWig tracks and QC summaries. No replicate merging or differential analysis in the standard preset.

## Start here

- [Quick start](quick-start.md) — create a run, fill three sample sheets, submit and collect results.
- [English user manual](MANUAL_EN.md).
- [中文用户手册](MANUAL_CN.md).
- [Validation scope](tests/README.md).

## Repository layout

| Location | Purpose |
|---|---|
| pipeline.env.example | Current standard configuration template |
| archive/configs/pipeline.advanced.env.example | Full options for experienced users |
| external_input.config.example | Shared Input container mount template |
| scripts/new_run.py | Creates all six run setup files |
| run_end2end_parallel_safe.sh | Default launcher used by generated submit.sh |
| run_end2end.sh | Sequential launcher for advanced use |
| docs/ | Supporting sample guide and developer walkthroughs |
| archive/legacy_docs/ | Retired quick-start documents; not current instructions |
| tests/ | Launcher validation |

Analysis files belong in the sibling `chip_runs/DATE_PERSON/`, not in code repos. Keep reusable `chip_runs/shared_input/` separate from individual runs. The local pipeline.env is a working preset; create a new run before submitting. Fixed references and shared control must match the experiment.

The latest documentation describes local changes; it does not imply those changes have been pushed or deployed to HPC.

Detailed tool settings, configured versions, output interpretation and launcher roles: [technical user manual](docs/USER_MANUAL_EN.md).
