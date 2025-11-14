# 📘 **ENCODE Standards for ChIP-seq and ATAC-seq**

The **ENCODE Consortium** has established widely adopted experimental and computational standards for ChIP-seq and ATAC-seq. These guidelines define the minimal quality thresholds, recommended processing steps, and reporting requirements to ensure reproducible and publication-grade functional genomics data. Pipelines described as “ENCODE-style” typically follow the principles below.

---

## **ChIP-seq Standards**

**Experimental & QC Metrics**

* **Replicates:** At least two biological replicates are required.
* **Mapping Rate:** ≥ 80% uniquely mapped reads recommended.
* **PCR Bottleneck Coefficients:**

  * **PBC1 ≥ 0.8**, **PBC2 ≥ 1** (library complexity).
* **NSC/RSC Cross-Correlation:**

  * **NSC ≥ 1.05** (minimum)
  * **RSC ≥ 0.8** (minimum)
* **FRiP (Fraction of Reads in Peaks):**

  * **> 1%** for broad marks; **> 5%** commonly seen for TFs.
* **Duplicate Reads:**

  * Mark duplicates for TFs; remove for broad marks.
* **Blacklist Removal:** Must remove reads overlapping ENCODE blacklist regions.

**Computational Workflow Requirements**

* Adapter trimming → alignment (BWA/Bowtie2) → filtering (MAPQ ≥ 30)
* Sorted, indexed BAM + detailed alignment statistics
* Peak calling with **MACS2/MACS3**, using matched **Input control**
* **IDR analysis** for replicated peak sets
* Generation of **bigWig signal tracks** (normalized)
* Comprehensive QC reporting (FastQC, phantompeakqualtools, MultiQC)

---

## **ATAC-seq Standards**

**Experimental & QC Metrics**

* **TSS Enrichment Score:** ENCODE requires **≥ 7**, high-quality libraries often > 10.
* **Fragment Length Distribution:** Clear periodic nucleosomal pattern
  (mononucleosome ~ 180 bp; dinucleosome ~ 350 bp).
* **Mapping Rate:** ≥ 80% uniquely mapped reads recommended.
* **Mitochondrial Reads:** Ideally **< 50%**, < 20% preferred.
* **PCR Bottleneck Coefficients (PBC1/PBC2):** Same thresholds as ChIP-seq.
* **NSC/RSC:** NSC ≥ 1.05; RSC ≥ 0.8.
* **FRiP:** Typically **> 20%** for high-quality open-chromatin data.
* **Blacklist Removal:** Mandatory.

**Computational Workflow Requirements**

* Adapter trimming (short-fragment read-through is common)
* Alignment with BWA/Bowtie2 → MAPQ filtering (≥ 30)
* Duplicate marking (do **not** remove unless over-amplification is suspected)
* **Tn5 offset correction** (+4/−5 bp shifts)
* Peak calling with **MACS2/MACS3**
* bigWig generation (RPKM/CPM normalized)
* QC visualization: TSS enrichment, fragment histograms, fingerprinting plots
* Final integrated QC report (FastQC, deepTools, MultiQC)

---

## **Summary**

ENCODE standards emphasize:

* High-quality library preparation
* Rigorous QC thresholds
* Strict alignment and filtering rules
* Reproducible computational workflows
* Replicate-aware peak calling (IDR)
* Transparent reporting and standardized outputs (BAM, bigWig, BED)

Pipelines that follow these rules are considered **ENCODE-compliant** and produce data suitable for publication, cross-study comparison, and integration into large-scale genomic analyses.

