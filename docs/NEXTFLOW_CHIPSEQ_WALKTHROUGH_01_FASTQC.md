# Nextflow ChIP-seq Walkthrough 01: FastQC

### Module: `nf-fastqc`

**Purpose**
- Perform raw read quality assessment before trimming/alignment
- Detect technical issues early (quality decay, adapter contamination, sequence bias)

**Input**
- FASTQ files (`.fastq.gz`)
- Source can be:
  - `--samples_master` (recommended)
  - or `--fastqc_raw_data` + `--fastqc_pattern`

**Output**
- `*_fastqc.html`
- `*_fastqc.zip`
- Published to `${project_folder}/${fastqc_output}`

**Key Parameters**
- `samples_master`: optional CSV with `fastq_r1/fastq_r2` (preferred for sample tracking)
- `fastqc_raw_data`: input directory (fallback mode)
- `fastqc_pattern`: file glob (default `*fastq.gz`)
- `fastqc_output`: output folder name
- `cpus/memory/time`: runtime resources

**Decision impact for downstream steps**
- Adapter signal high -> tune `fastp/cutadapt`
- 3' quality drop -> trim tail
- Severe outlier sample -> flag for cautious interpretation

---

## How To Read the FastQC Report

### Priority checks (in order)

1. **Per base sequence quality**
- Expect most positions near Q30 or above
- Strong tail drop suggests end trimming

2. **Adapter Content**
- Rising curve toward 3' end indicates adapter contamination
- Use this to justify trimming settings in `fastp`

3. **Overrepresented sequences**
- Often adapters/primers
- Unexpected entries may suggest contamination

4. **Per sequence GC content**
- Should be broadly plausible for organism/library
- Major shift can indicate bias or contamination

5. **Per base N content**
- Should remain low
- Elevated N% suggests unstable base calls

### Practical interpretation rule
- One warning alone is common; focus on consistent multi-metric problems
- Compare all samples together (MultiQC is best for this)

