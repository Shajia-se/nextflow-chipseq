# Nextflow ChIP-seq Walkthrough 06: MACS3

## Slide Content (1 slide)

### Module: `nf-macs3`

**Purpose**
- Call ChIP peaks with matched control/input BAM
- Produce two peak profiles for downstream branches
- Apply **peak-level blacklist filtering** after callpeak

**Input**
- Preferred priority:
  1. `--macs3_samplesheet` (`sample_id,treatment_bam,control_bam`)
  2. `--samples_master` (auto-generate treatment/control pairs)
- BAM source is usually `nf-chipfilter/chipfilter_output/*.clean.bam`

**Output (two MACS3 branches)**
- `idr_q0.1/${sample}_peaks.narrowPeak`
- `strict_q0.01/${sample}_peaks.narrowPeak`
- `${sample}_peaks.xls`
- `${sample}_summits.bed` (if enabled)
- `${sample}_treat_pileup.bdg`, `${sample}_control_lambda.bdg`
- `${sample}_peaks.blacklist_applied.txt` (new: peak blacklist report)

**Key Parameters (current defaults)**
- `seq="paired"` -> `-f BAMPE`
- `genome_size="mm"`
- `idr_qvalue=0.1`
- `strict_qvalue=0.01`
- `keep_dup="all"`
- `call_summits=true`
- `peak_blacklist_bed=/.../mm39.excluderanges.bed`
- `peak_blacklist_fraction=0.5`

**Branch mapping**
- `idr_q0.1` -> `nf-idr`
- `strict_q0.01` -> `nf-peak-consensus`, `nf-diffbind`

---

## Oral Presentation (~90 sec)

This module performs peak calling with MACS3 using treatment-control pairs.
Compared with the earlier version, we now always generate two output branches: one relaxed branch at q<0.1 for IDR, and one strict branch at q<0.01 for consensus and differential workflows.

A recent update is that we now also perform peak-level blacklist filtering after callpeak.
So both branches are cleaned against mm39 blacklist regions, and each sample writes a `blacklist_applied` report with before/after peak counts.

This setup keeps branch intent clear: IDR gets a broader candidate set, while strict analyses use higher-confidence peaks.

---

## How To Interpret MACS3 Results

1. **Check branch completeness**
- Each sample should exist in both `idr_q0.1` and `strict_q0.01`.

2. **Check blacklist effect**
- Review `${sample}_peaks.blacklist_applied.txt` for before/after counts.

3. **Compare peak counts between branches**
- `strict_q0.01` should generally have fewer peaks than `idr_q0.1`.

4. **Use branch-appropriate downstreams**
- Do not feed `strict_q0.01` to IDR by mistake.

