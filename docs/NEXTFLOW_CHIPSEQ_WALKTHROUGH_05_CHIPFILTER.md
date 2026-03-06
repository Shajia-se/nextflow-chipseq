# Nextflow ChIP-seq Walkthrough 05: ChipFilter

### Module: `nf-chipfilter`

**Purpose**
- Post-alignment cleanup before peak calling
- Remove low-confidence/multi-mapped reads, blacklist-overlapping reads, and mitochondrial reads

**Input**
- From `--chipfilter_raw_bam` (usually `nf-picard/picard_output`)
- Input preference:
  - `prefer_dedup=true` (default): use `*.dedup.bam`, fallback to `*.markdup.bam`
  - `prefer_dedup=false`: reverse priority
- Optional `--samples_master` to process only enabled `sample_id`

**Filtering order**
1. MAPQ filter (`samtools view -q`)
2. Blacklist filter (`bedtools intersect -v`) if `blacklist_bed` is set
3. Mitochondrial removal (`chrM`/`MT`)

**Output**
- `${sample}.nomulti.bam` + `.bai`
- `${sample}.noblack.bam` + `.bai` (if blacklist enabled)
- `${sample}.clean.bam` + `.bai`

**Key Parameters**
- `mapq_threshold` (default: `4`)
- `blacklist_bed`
- `prefer_dedup`
- `samples_master` (optional sample restriction)

**Decision impact for downstream**
- Directly affects FRiP, MACS3 peak counts, and signal-to-noise in tracks/heatmaps

---

## Oral Presentation (speaker-friendly, ~90 sec)

---

## How To Interpret ChipFilter Results

### Priority checks (in order)

1. **Read retention after each stage**
- Compare read counts from `nomulti`, `noblack`, and `clean`
- Sudden large drops may indicate too strict settings or problematic sample quality

2. **MAPQ threshold reasonableness**
- `MAPQ=4` is a permissive, commonly used lower cutoff
- Higher cutoffs increase specificity but can reduce depth and sensitivity

3. **Blacklist impact**
- Some decrease is expected
- Extremely large decrease suggests data enrichment in problematic regions

4. **Mitochondrial fraction**
- mtDNA removal should reduce non-informative reads
- Very high mtDNA fraction can indicate sample prep/library issues

5. **Cross-sample consistency**
- Filtering behavior should be comparable across replicates in the same condition

### Practical interpretation rule
- Use one consistent filtering policy for all samples in a contrast; avoid per-sample tuning.

