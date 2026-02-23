# Nextflow ChIP-seq Walkthrough 04: Picard

### Module: `nf-picard`

**Purpose**
- Handle duplicate reads and generate BAM-level QC metrics
- Prepare high-confidence BAM input for `nf-chipfilter`

**Input**
- From `--bwa_output`: `*.sorted.bam`
- Optional: `--samples_master` to process only enabled `sample_id`
- Behavior controlled by:
  - `--remove_duplicates true` (default): output `dedup` BAM
  - `--remove_duplicates false`: output `markdup` BAM

**Output**
- If `remove_duplicates=true`:
  - `${sample}.dedup.bam`
  - `${sample}.dedup.bam.bai`
  - `${sample}.dedup.metrics.txt`
- If `remove_duplicates=false`:
  - `${sample}.markdup.bam`
  - `${sample}.markdup.bam.bai`
  - `${sample}.markdup.metrics.txt`
- QC reports (both modes):
  - `${sample}.insert_size.txt`
  - `${sample}.insert_size.pdf`
  - `${sample}.align_summary.txt`

**Key Parameters**
- `bwa_output`: upstream BAM folder
- `samples_master`: optional sample restriction
- `picard_output`: output folder
- `remove_duplicates`: duplicate handling strategy
- `cpus/memory/time`: compute resources

**Decision impact for downstream**
- Dedup choice affects read depth, FRiP, and peak counts
- QC metrics here provide early warning for library complexity/fragment quality

---

## How To Read Picard Reports

### A) `*.insert_size.txt` and `*.insert_size.pdf`

Focus on:
1. **Median insert size**
- Should be biologically plausible and broadly consistent across replicates

2. **Distribution shape**
- Single clear peak is typical
- Very broad or irregular shape can indicate library prep issues

3. **Outlier samples**
- One sample with very different insert distribution should be flagged

### B) `*.align_summary.txt`

Focus on:
1. **TOTAL_READS / PF_READS**
- Basic sequencing yield and pass-filter status

2. **PCT_PF_READS_ALIGNED**
- Core alignment success metric

3. **PF_MISMATCH_RATE and bad-end metrics**
- High mismatch or poor end behavior can indicate quality/reference issues

4. **Cross-sample consistency**
- Relative differences between replicates are often more informative than one absolute threshold

### Practical interpretation rule
- Use Picard metrics as trend and outlier detectors, not isolated pass/fail gates.

---

## Suggested Talking Point: Why dedup in Picard if chipfilter comes next?

- `nf-chipfilter` focuses on MAPQ/blacklist/mitochondrial filters.
- Duplicate handling is conceptually separate and is best done explicitly here.
- Keeping `remove_duplicates` configurable preserves flexibility for low-depth or special library scenarios.
