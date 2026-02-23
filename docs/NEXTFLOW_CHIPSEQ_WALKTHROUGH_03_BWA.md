# Nextflow ChIP-seq Walkthrough 03: BWA Mapping

### Module: `nf-bwa`

**Purpose**
- Align trimmed paired-end reads to reference genome
- Produce sorted/indexed BAM for downstream QC, peak calling, and differential analysis

**Input**
- Preferred: `--samples_master` (uses `sample_id`, optional `enabled`)
- Fallback: `--bwa_raw_data` + `--bwa_pattern`
- Reference settings:
  - `--genomes`
  - `--organism`
  - `--release`
  - `--reference_fasta`

**Output**
- `${sample}.sam`
- `${sample}.bam`
- `${sample}.bam.stat` (from `samtools flagstat`)
- `${sample}.sorted.bam`
- `${sample}.sorted.bam.bai`

**Key Parameters**
- `samples_master`: preferred sample source
- `bwa_raw_data`: directory of Fastp trimmed FASTQ
- `bwa_pattern`: fallback file pattern
- `cpus/memory/time`: runtime resources

**Decision impact for downstream**
- Mapping quality influences duplicate marking, filtering, FRiP, and peak quality
- Low mapping rate often indicates reference mismatch, contamination, or trimming issues

---

## How To Read BWA Mapping Outputs

### Priority checks 

1. **`*.bam.stat` overall mapping rate**
- Use `% mapped` as the first health check
- Very low values suggest input/reference mismatch or poor library quality

2. **Properly paired rate (for paired-end)**
- Low properly paired fraction can indicate fragment/library issues

3. **Secondary/supplementary alignments**
- Excessive non-primary alignments may indicate repetitive or problematic reads

4. **Read depth retained after mapping**
- Ensure enough mapped reads remain for peak calling and FRiP interpretation

5. **Cross-sample consistency**
- Compare mapping metrics across replicates
- One outlier sample should be flagged early

### Practical interpretation rule
- Mapping is not only “pass/fail”; relative consistency across replicates is critical for trustworthy downstream contrasts.


## Common Mapping Tools Comparison

### When to use which aligner?

| Tool | Best for | Strengths | Limitations |
|---|---|---|---|
| **BWA-MEM** | DNA reads (ChIP-seq, ATAC-seq, WGS) | Robust, widely used, good default for ChIP-seq | Not designed for splice-aware RNA alignment |
| **Bowtie2** | DNA reads, fast standard alignments | Fast, lightweight, common in legacy ChIP/ATAC pipelines | Can be slightly less robust on longer/complex reads vs BWA in some settings |
| **STAR** | RNA-seq (spliced alignment) | Very fast for transcriptome-scale spliced mapping | Overkill for ChIP-seq; large memory footprint |
| **HISAT2** | RNA-seq (spliced), moderate resources | Lower memory than STAR, splice-aware | Not a primary choice for ChIP-seq DNA mapping |
| **minimap2** | Long reads (ONT/PacBio), assembly mapping | Excellent for long reads, versatile | Not standard for short-read ChIP-seq |
| **BWA-MEM2** | DNA short reads with CPU optimization | Faster implementation of BWA-MEM on many systems | Output behavior generally similar, but environment compatibility needs validation |

### Recommendation for your pipeline

- Keep **BWA-MEM** as default for short-read ChIP-seq.
- Consider **Bowtie2** only if your team prefers legacy comparability or specific speed/resource constraints.
- Do **not** switch to STAR/HISAT2 for ChIP-seq genomic DNA alignment.
