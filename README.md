# **nextflow-chipseq**

**nextflow-chipseq** is a modular, reproducible, and fully customizable Nextflow pipeline for processing and analyzing **Chromatin Immunoprecipitation sequencing (ChIP-seq)** data.
The workflow follows community and ENCODE-style best practices, supporting multiple tools for each analysis step and enabling straightforward extension to ATAC-seq or CUT&RUN pipelines.

This pipeline is designed for flexibility and clarity — each analytical step is implemented as an independent Nextflow DSL2 module, making it easy to reuse, replace, or extend.

---

## 🔬 **Pipeline Summary**

### **1. Quality Control**

* **FastQC**, **MultiQC**
  Modules: `nf-fastqc`, `nf-multiqc`
  Generate per-sample QC reports and aggregated summaries.

---

### **2. Adapter Trimming**

Options:

* **fastp**
* **cutadapt**
* **Flexbar**

Modules: `nf-fastp`, `nf-cutadapt`, `nf-flexbar`

---

### **3. Alignment**

Supported aligners:

* **Bowtie2**
* **BWA / BWA-MEM2**
* **STAR**
  
Modules: `nf-star`, `nf-bowtie`, `nf-bwa`
Post-alignment processing (via samtools):

* `samtools view`
* `samtools sort`
* `samtools flagstat`
* `samtools stats`

Module: `nf-samtools`

---

### **4. PCR Duplicate Handling**

* Picard MarkDuplicates
* samtools markdup

Module: `markduplicates.nf`

---

### **5. Read Filtering**

* Remove low-quality reads (e.g., MAPQ < 30)
* Remove unmapped / secondary / supplementary alignments

Tools: **samtools**, **bamtools**

---

### **6. Fragment Length Estimation**

* **deepTools** (`bamPEFragmentSize`)
* **phantompeakqualtools** (NSC/RSC)

Module: `nf-deeptools_fragment` (optional)

---

### **7. Peak Calling**

Using **MACS3**:

* **Narrow peaks** (TF)
* **Broad peaks** (H3K27me3 / H3K36me3)

Module: `nf-macs3`

---

### **8. Peak QC & Cross-Correlation Metrics**

Assess library complexity and peak quality:

* phantompeakqualtools
* deepTools fingerprinting

---

### **9. Peak Annotation & Functional Analysis**

Supported tools:

* **HOMER** (motif discovery, annotation)
* **ChIPseeker** (R)
* **annotatr**
* **GREAT** (distal regulatory regions)

Modules: `nf-homer`, `nf-chipseeker`

---

### **10. Signal Track Generation**

Create bigWig files for visualization:

* **deepTools bamCoverage**
* **bedGraphToBigWig**

Modules: `nf-bamcoverage` or `nf-bedgraphtobigwig`

---

### **11. Visualization**

Outputs ready for:

* **IGV**
* **deepTools plotHeatmap / plotProfile**

---

### **12. Differential Binding Analysis**

Tools:

* **DiffBind**
* **csaw**

(Implemented as optional downstream R modules.)

---

### **13. MultiQC Final Report**

Aggregated report summarizing all QC and processing steps.

---

---

## 📁 **Directory Structure**

```
project/
 ├── main.nf
 ├── nextflow.config
 ├── modules/
 │     ├── qc/
 │     │    ├── fastqc.nf
 │     │    ├── multiqc.nf
 │     ├── trimming/
 │     │    ├── fastp.nf
 │     │    ├── cutadapt.nf
 │     │    ├── flexbar.nf
 │     ├── alignment/
 │     │    ├── bwa_mem2.nf
 │     │    ├── bowtie2.nf
 │     │    ├── star.nf
 │     │    ├── samtools_sort.nf
 │     │    ├── markduplicates.nf
 │     ├── peakcalling/
 │     │    ├── macs3.nf
 │     ├── stats/
 │     │    ├── deeptools_fragment.nf
 │     ├── annotation/
 │     │    ├── homer.nf
 │     │    ├── chipseeker.nf
 │     └── tracks/
 │          ├── bamcoverage.nf
 ├── conf/
 │     ├── base.config
 │     ├── cluster.config
 └── assets/
       ├── genome.fa
       ├── blacklist.bed
```

This modular design enables isolated execution and easy reuse of individual steps across other sequencing pipelines.

---
下面是**可直接嵌入你当前 README 的精简 ENCODE 标准段落**，格式、语气、长度都与前面 README 风格一致。
你可以直接复制进 README 中的 **“ENCODE Standards”** 小节。

---

## 📘 **ENCODE Standards for ChIP-seq and ATAC-seq**

This pipeline follows key ENCODE-style guidelines to ensure high-quality, reproducible, and publication-ready chromatin profiling data. Below is a concise summary of the major ENCODE standards and the tools used to satisfy each requirement.

---

### **ChIP-seq (ENCODE Summary)**

**Quality Criteria**

* **Biological replicates:** ≥ 2
  *Tools:* IDR
* **Mapping rate:** ≥ ~80% uniquely mapped
  *Tools:* BWA / Bowtie2, samtools flagstat
* **Library complexity:** PBC1 ≥ 0.8, PBC2 ≥ 1
  *Tools:* phantompeakqualtools, ChIPQC
* **Cross-correlation:** NSC ≥ 1.05, RSC ≥ 0.8
  *Tools:* phantompeakqualtools
* **FRiP:** ≥ 1–5%
  *Tools:* MACS2/MACS3, bedtools intersect
* **Blacklist removal**
  *Tools:* bedtools subtract

**Required Processing Steps**

* Adapter trimming → fastp / cutadapt / Flexbar
* Alignment → BWA / Bowtie2
* Mapping quality filtering (MAPQ ≥ 30) → samtools
* Duplicate handling → Picard / samtools markdup
* Peak calling → MACS2/MACS3
* Replicate consistency → IDR
* bigWig signal tracks → deepTools bamCoverage

---

### **ATAC-seq (ENCODE Summary)**

**Quality Criteria**

* **TSS enrichment:** ≥ 7 (high-quality > 10)
  *Tools:* deepTools computeMatrix + plotProfile
* **Fragment length periodicity:** clear mono-/di-nucleosome peaks
  *Tools:* deepTools bamPEFragmentSize
* **Mapping rate:** ≥ ~80%
  *Tools:* BWA / Bowtie2, samtools flagstat
* **Mitochondrial reads:** ideally < 20–50%
  *Tools:* samtools idxstats
* **Library complexity:** PBC1 ≥ 0.8, PBC2 ≥ 1
  *Tools:* phantompeakqualtools
* **Cross-correlation:** NSC ≥ 1.05, RSC ≥ 0.8
  *Tools:* phantompeakqualtools
* **FRiP:** > 20% typical
  *Tools:* MACS2/MACS3, bedtools intersect
* **Blacklist removal**
  *Tools:* bedtools subtract

**Required Processing Steps**

* Adapter trimming → fastp / cutadapt / Flexbar
* Alignment → BWA / Bowtie2
* Filtering (MAPQ ≥ 30) → samtools
* Duplicate marking → Picard / samtools
* **Tn5 shift correction** → MACS2 or deepTools alignmentSieve
* Peak calling → MACS2/MACS3
* bigWig tracks → deepTools bamCoverage

