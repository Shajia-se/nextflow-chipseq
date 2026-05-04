# Nextflow ChIP-seq Walkthrough 05: ChipFilter

### Module: `nf-chipfilter`

**Purpose**
- Post-alignment cleanup before peak calling
- Remove low-confidence/multi-mapped reads and record mitochondrial burden without writing a second filtered BAM

**Input**
- From `--chipfilter_raw_bam` (usually `nf-picard/picard_output`)
- Input preference:
  - `prefer_dedup=true` (default): use `*.dedup.bam`, fallback to `*.markdup.bam`
  - `prefer_dedup=false`: reverse priority
- Optional `--samples_master` to process only enabled `sample_id`

**Filtering order**
1. MAPQ filter (`samtools view -q`)
2. Mitochondrial QC from the MAPQ-filtered BAM (`chrM`/`MT`)

**Output**
- `${sample}.nomulti.bam` + `.bai`
- `${sample}.chipfilter.stats.tsv`

**Key Parameters**
- `mapq_threshold` (default: `24`)
- `prefer_dedup`
- `samples_master` (optional sample restriction)

**Decision impact for downstream**
- Directly affects FRiP, MACS3 peak counts, and signal-to-noise in tracks/heatmaps

---

## Oral Presentation (speaker-friendly, ~90 sec)

---

## How To Interpret ChipFilter Results

### Priority checks (in order)

1. **Read retention after MAPQ filtering**
- Compare `nomulti_reads` to the upstream aligned read counts
- Sudden large drops may indicate too strict settings or problematic sample quality

2. **MAPQ threshold reasonableness**
- `MAPQ=24` is the current default in this pipeline
- Higher cutoffs increase specificity but can reduce depth and sensitivity

3. **Mitochondrial fraction**
- mtDNA removal should reduce non-informative reads
- Very high mtDNA fraction can indicate sample prep/library issues

4. **Cross-sample consistency**
- Filtering behavior should be comparable across replicates in the same condition

### Practical interpretation rule
- Use one consistent filtering policy for all samples in a contrast; avoid per-sample tuning.
