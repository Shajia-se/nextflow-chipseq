# Nextflow ChIP-seq Walkthrough 02: Fastp

### Module: `nf-fastp`

**Purpose**
- Perform read trimming and filtering before alignment
- Remove adapter contamination and low-quality tails
- Generate QC reports to document what was trimmed/filtered

**Input**
- Preferred: `--samples_master` with `sample_id,fastq_r1,fastq_r2`
- Fallback: `--fastp_raw_data` + `--fastp_pattern`
- Paired-end FASTQ required in current module

**Output**
- `${sample}_R1.fastp.trimmed.fastq.gz`
- `${sample}_R2.fastp.trimmed.fastq.gz`
- `${sample}.fastp.html`
- `${sample}.fastp.json`
- Published to `${project_folder}/${fastp_output}`

**Key Parameters**
- `samples_master`: preferred input mode
- `fastp_raw_data`, `fastp_pattern`: fallback input mode
- `fastp_output`: output directory name
- `cpus/memory/time`: runtime resources

**Decision impact for downstream steps**
- Better mapping rate and cleaner peak calling
- Too aggressive trimming can reduce depth and sensitivity
- Fastp report is used to verify trimming is effective but not excessive

---

## How To Read the Fastp Report

### Priority checks (in order)

1. **Total reads before vs after filtering**
- Moderate loss is expected
- Large loss (for example >30%) needs review of quality and trimming settings

2. **Q20 / Q30 improvement after filtering**
- Should increase after Fastp
- If no improvement, trimming settings may be too weak

3. **Adapter trimming statistics**
- Confirm adapters were detected/trimmed if FastQC suggested contamination
- If adapter content remains high, tighten trimming settings

4. **Read length distribution after filtering**
- Should remain biologically reasonable and fairly consistent
- Extreme shortening suggests over-trimming

5. **Duplication and overrepresented sequences**
- High duplication may be biological or technical; interpret with library context
- Persistent suspicious overrepresented sequences may indicate contamination

### Practical interpretation rule
- Goal is improvement, not maximal filtering
- Compare all samples together and flag outliers for downstream caution
