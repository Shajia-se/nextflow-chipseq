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
8. `nf-chipseeker`
9. `nf-frip`
10. `nf-bamcoverage`
11. `nf-deeptools-heatmap` (optional)
12. `nf-homer --mode motif_compare` (optional)
13. `nf-diffbind` (optional)
14. `nf-result-delivery` (optional)

## For Non-coders: Quick Start

1. Copy and edit config:

```bash
cd /ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/nextflow-chipseq
cp pipeline.env.example pipeline.env
```

2. In `pipeline.env`, set these first:

- `PIPELINES_ROOT`
- `RAW_DATA_DIR`
- `REFERENCE_FASTA`
- `GTF`
- sheet file paths (`MACS3_SAMPLESHEET`, `IDR_PAIRS_CSV`, `DIFFBIND_SAMPLESHEET`, `FRIP_SAMPLESHEET`, `DEEPTOOLS_REGIONS_SHEET`, `HOMER_MOTIF_COMPARE_SHEET`)

3. Run everything:

```bash
bash run_end2end.sh pipeline.env
```

## Required Sheet Templates

Templates are under `templates/`:

- `idr_pairs.example.csv`
- `frip_samplesheet.example.csv`
- `deeptools_regions_sheet.example.csv`
- `motif_compare_sheet.example.csv`

Use your existing module sheets for:

- MACS3: `nf-macs3/macs3_samplesheet.csv`
- DiffBind: `nf-diffbind/samplesheet.csv`

## Notes

- Set `RESUME=true` in `pipeline.env` to resume from previous runs.
- Optional modules can be disabled via toggles in `pipeline.env`.
- The launcher validates key input paths before starting.
