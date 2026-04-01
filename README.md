# nextflow-chipseq (Launcher)

This folder provides a **one-command launcher** to run your modular ChIP-seq workflow end-to-end.

It orchestrates these modules in dependency order:

1. `nf-fastqc`
2. `nf-fastp`
3. `nf-bwa`
4. `nf-picard`
5. `nf-chipfilter`
6. `nf-macs3`
7. `nf-idr` (from `macs3/idr_q0.1`)
8. `nf-peak-consensus` (optional; from `macs3/strict_q0.01`)
9. `nf-diffbind` (optional; from `macs3/strict_q0.01`)
10. `nf-bamcoverage`
11. `nf-frip`
12. `nf-chipseeker`
13. `nf-homer` (optional)
14. `nf-deeptools-heatmap` (optional)
15. `nf-result-delivery` (optional)
16. `nf-multiqc` (optional)

## For Non-coders: Quick Start

1. Copy and edit config:

```bash
cd /ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/nextflow-chipseq
cp pipeline.env.example pipeline.env
```

2. In `pipeline.env`, set these first:

- `PIPELINES_ROOT`
- `OUTPUT_PROJECT_ROOT`
- `SAMPLES_MASTER`
- `REFERENCE_FASTA`
- `GTF`

Useful optional run controls:

- `MAPQ_THRESHOLD`
- `MACS3_QVALUE_IDR`
- `MACS3_QVALUE_CONSENSUS`
- `MACS3_QVALUE_STRICT`
- `MACS3_RUN_IDR_BRANCH`
- `MACS3_RUN_CONSENSUS_BRANCH`
- `MACS3_RUN_STRICT_BRANCH`

By default, downstream sheets are auto-generated from `SAMPLES_MASTER`. Keep optional sheet vars empty unless you intentionally want manual override.

3. Run everything:

```bash
bash run_end2end.sh pipeline.env
```

4. Continue from a specific module (recommended for testing):

- In `pipeline.env`, set:
  - `START_FROM=picard` (example)
  - `RESUME=true`
  - keep module toggles (`RUN_*=true/false`) as needed

Then run:

```bash
bash run_end2end_parallel_safe.sh pipeline.env
```

## Output Layout

Launcher output is now organized under a flat run root:

```bash
${OUTPUT_PROJECT_ROOT}/${RUN_ID}/
  fastqc_output/
  fastp_output/
  bwa_output/
  picard_output/
  chipfilter_output/
  macs3_output/
  ...
```

This keeps each run isolated while preserving familiar module-style folder names.

## Samples Master Guide

Detailed field-by-field guidance is here:

- `docs/SAMPLES_MASTER_GUIDE.md`

## Walkthrough Doc Order (recommended)

1. `docs/NEXTFLOW_CHIPSEQ_WALKTHROUGH_00_CURRENT_FLOW.md`
2. `docs/NEXTFLOW_CHIPSEQ_WALKTHROUGH_01_FASTQC.md`
3. `docs/NEXTFLOW_CHIPSEQ_WALKTHROUGH_02_FASTP.md`
4. `docs/NEXTFLOW_CHIPSEQ_WALKTHROUGH_03_BWA.md`
5. `docs/NEXTFLOW_CHIPSEQ_WALKTHROUGH_04_PICARD.md`
6. `docs/NEXTFLOW_CHIPSEQ_WALKTHROUGH_05_CHIPFILTER.md`
7. `docs/NEXTFLOW_CHIPSEQ_WALKTHROUGH_06_MACS3.md`
8. `docs/NEXTFLOW_CHIPSEQ_WALKTHROUGH_07_IDR.md`
9. `docs/NEXTFLOW_CHIPSEQ_WALKTHROUGH_07B_PEAK_CONSENSUS.md`
10. `docs/NEXTFLOW_CHIPSEQ_WALKTHROUGH_12_DIFFBIND.md`
11. `docs/NEXTFLOW_CHIPSEQ_WALKTHROUGH_09_FRIP.md`
12. `docs/NEXTFLOW_CHIPSEQ_WALKTHROUGH_10_BAMCOVERAGE.md`
13. `docs/NEXTFLOW_CHIPSEQ_WALKTHROUGH_08_CHIPSEEKER.md`
14. `docs/NEXTFLOW_CHIPSEQ_WALKTHROUGH_13_HOMER.md`
15. `docs/NEXTFLOW_CHIPSEQ_WALKTHROUGH_11_DEEPTOOLS_HEATMAP.md`

## Notes

- Set `RESUME=true` in `pipeline.env` to resume from previous runs.
- By default, both peak branches run: `RUN_IDR=true` and `RUN_PEAK_CONSENSUS=true`.
- `nf-idr` consumes `nf-macs3` profile `idr_q0.1`.
- `nf-peak-consensus` consumes `nf-macs3` profile `strict_q0.01`.
- `nf-macs3` now applies peak-level blacklist filtering on both branches by default.
- `nf-chipfilter` current default flow does not apply BAM-level blacklist filtering.
- `run_end2end.sh` now auto-selects downstream peak sources for `nf-frip`, `nf-chipseeker`, and `nf-homer` based on enabled upstream branches. You can override them with `FRIP_PEAK_SOURCES`, `CHIPSEEKER_PEAK_SOURCES`, and `HOMER_PEAK_SOURCES` in `pipeline.env`.
- `nf-deeptools-heatmap` current workflow is auto-driven from `samples_master + chipfilter + macs3(strict) + diffbind` (no manual regions/group sheets required).
- Optional modules can be disabled via toggles in `pipeline.env`.
- Core modules can also be toggled now (`RUN_FASTQC`, `RUN_FASTP`, `RUN_BWA`, `RUN_PICARD`, `RUN_CHIPFILTER`, `RUN_MACS3`, etc.).
- The launcher validates key input paths before starting.
- `OUTPUT_PROJECT_ROOT` defines the project-level destination, and `RUN_ID` creates the per-run subfolder used by all modules.
