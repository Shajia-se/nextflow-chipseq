# nextflow-chipseq (Launcher)

This folder provides a **one-command launcher** to run your modular ChIP-seq workflow end-to-end.

It orchestrates these modules in order:

1. `nf-fastqc`
2. `nf-fastp`
3. `nf-bwa`
4. `nf-picard`
5. `nf-chipfilter`
6. `nf-macs3`
7. `nf-idr`
8. `nf-peak-consensus` (optional)
9. `nf-frip`
10. `nf-bamcoverage`
11. `nf-diffbind` (optional)
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
- `SAMPLES_MASTER`
- `REFERENCE_FASTA`
- `GTF`

By default, downstream sheets are auto-generated from `SAMPLES_MASTER`. Keep optional sheet vars empty unless you intentionally want manual override.

3. Run everything:

```bash
bash run_end2end.sh pipeline.env
```

## Samples Master Guide

Detailed field-by-field guidance is here:

- `docs/SAMPLES_MASTER_GUIDE.md`

## Notes

- Set `RESUME=true` in `pipeline.env` to resume from previous runs.
- By default, both peak branches run: `RUN_IDR=true` and `RUN_PEAK_CONSENSUS=true`.
- `nf-idr` consumes `nf-macs3` profile `idr_q0.1`.
- `nf-peak-consensus` consumes `nf-macs3` profile `strict_q0.01`.
- Optional modules can be disabled via toggles in `pipeline.env`.
- The launcher validates key input paths before starting.
