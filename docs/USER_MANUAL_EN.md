# Technical user manual — ChIP-seq handoff

Configuration reviewed: 2026-09-14, current local source. This documents the configured software and commands, not an assertion that this revision has completed on HPC. Run acceptance requires reviewing the run's logs and outputs.

## Operating workflow

Use [quick-start.md](../quick-start.md) for creation, CSV examples, submission and monitoring. The standard workflow is mouse paired-end narrow-peak analysis with GRCm39/vM27 and processed shared liver Input 25L007941. Each new ChIP sample is processed independently. There is no sample merging, IDR, consensus peak construction or differential binding in this preset.

```text
New ChIP FASTQ pairs → FastQC → fastp → BWA → Picard → chipfilter
                                                      ├─ MACS3 q=0.05 / q=0.01 ← existing Input BAM
                                                      └─ bamCoverage
Module reports → MultiQC → delivery summaries
```

This shows data dependencies, not exact parallel scheduling. Reference/control suitability must be assessed for the experiment; fixed liver Input is not a universal control for all tissues or assays.

## Launchers: what to keep

Keep `run_end2end_parallel_safe.sh`: generated `submit.sh` calls it and it is the standard launcher. It waits for dependency waves and stops downstream launch after failures. A run lock prevents two launchers sharing one run directory.

Retain `run_end2end.sh` as a developer troubleshooting fallback. It launches modules sequentially with streamed console output; Nextflow tasks inside a module can still run in parallel. Existing tests cover both scripts. Deleting or moving it would break older commands; it is not necessary for ordinary users to choose between them. Do not run both for the same run. Users should use only `sbatch submit.sh`.

Neither script is an output file. Keep `scripts/run_common.sh` and `scripts/run_layout.py`, which provide shared execution and path handling. This documentation update does not change either launcher's behavior.

## Software versions and provenance

The versions below are **configured container labels**, taken from module `nextflow.config` and `configs/slurm.config`. A SIF filename is not proof of the binary's exact version or immutable content. Unversioned images are explicitly marked. Record actual executable versions and image hashes when freezing a deployment; do not infer them from the host environment.

| Module | Configured HPC image basename | Version indicated |
|---|---|---|
| nf-fastqc | fastqc-0.11.9.sif | FastQC 0.11.9 |
| nf-fastp | fastp-1.0.1.sif | fastp 1.0.1 |
| nf-bwa | bwa-sam.sif | BWA/SAMtools versions unspecified |
| nf-picard | picard-2.27.4-samtools.sif | Picard 2.27.4; SAMtools unspecified |
| nf-chipfilter | samtools-bedtools-py3.sif | SAMtools/BEDTools/Python unspecified |
| nf-macs3 | macs3-3.0.1.sif | MACS3 3.0.1 |
| nf-bamcoverage | deeptools-3.5.6.sif | deepTools 3.5.6 |
| nf-multiqc | multiqc-1.32.sif | MultiQC 1.32 |
| nf-result-delivery | samtools-bedtools-py3.sif | Custom script plus bundled tools, unspecified |

Images are configured under `/ictstr01/groups/idc/projects/uhlenhaut/jiang/singularity_image/`. Custom configs can override them. Bash, Python 3.8+, Java/Nextflow and Singularity must be available in the batch environment. Native local tests previously used Nextflow 25.10.0; read the run's Nextflow log for the actual deployed version.

`02_run_record/<attempt>/code_versions.json` records Git commits, working-tree status and selected source hashes. Saved diffs, env/CSV snapshots, `logs/<module>/runtime.config`, command/status records and Nextflow logs document what was requested. These records do not automatically checksum every FASTQ, reference or SIF.

## Input contract and fixed reference

The master sheet contains only new paired-end ChIP samples. All three CSVs must use matching unique sample IDs; edits are not automatically synchronized. No global cross-sheet validation currently guarantees consistency.

| File | Required fields / role |
|---|---|
| samples_master.csv | sample_id, condition, replicate, library_type, fastq_r1, fastq_r2, is_control, control_id, use_for_idr, use_for_diffbind, enabled |
| macs3_samplesheet.csv | sample_id,treatment_bam,control_bam; empty treatment_bam resolves this run's filtered BAM |
| shared_control_manifest.csv | sample_id,control_id,control_root; records control identity and previous QC |
| external_input.config | Mounts the control root for container access |

For independent samples use replicate=1, is_control=false, blank master control_id, use_for_idr=false and use_for_diffbind=false. Keep enabled=true for selected samples. Use actual condition labels and absolute FASTQ paths, without spaces, commas or shell metacharacters. Preserve R1/R2 order.

Reference FASTA: `/ictstr01/groups/idc/projects/uhlenhaut/jiang/reference/bwa/GRCm39_vM27/GRCm39.primary_assembly.genome.fa`.

GTF: `/ictstr01/groups/idc/projects/uhlenhaut/jiang/reference/gtf/gencode.vM27.primary_assembly.annotation.gtf`.

Shared control root: `/ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/chip_runs/shared_input/liver/25L007941`.

MACS3 control: `chipfilter_output/25L007941.nomulti.bam` under that root. Its index is stored alongside it. The manifest uses the root, not the BAM path. The mount exposes the root and its QC subfolders. The standard does not reprocess this Input or include it in the new FASTQ sheet. FASTA selection alone does not configure another species: MACS3 genome size and bamCoverage effective genome size are separate settings.

## Paths and parameter precedence

In this manual, RUN means `pipelines/chip_runs/DATE_PERSON`. Results are under RUN, never `nf-tool/tool_output` in the standard launcher. RUNNER is a label, not a folder level. Each new analysis gets one RUN_ID; generated absolute paths mean folders must not be moved casually.

`pipeline.env` selects modules and passes explicit command arguments. Tool-specific defaults reside in each module's config and script. `NEXTFLOW_CONFIG` adds a config, after which run_layout applies run path/mount handling. Inspect the saved command and runtime config for a run rather than assuming a setting in an unused template took effect.

| Run directory | Contents |
|---|---|
| *_output/ | Copy-published results from enabled modules |
| 02_run_record/<attempt>/ | Configuration, versions, diffs, commands and logs |
| 99_intermediate/execution/nf-*/ | Launch directory, Nextflow cache/history |
| 99_intermediate/work/nf-*/ | Task working directories and command files |
| 99_intermediate/tmp/ | Temporary files |
| 99_intermediate/reference/bwa/ | Run-local BWA index or links to a matching existing index |
| 99_intermediate/container_cache/ | Run-local Singularity cache |

## FastQC — raw read assessment

**Input:** enabled R1 and R2 FASTQs from samples_master. **Output:** `RUN/fastqc_output/*_fastqc.html` and `*_fastqc.zip`, generally one report per FASTQ; names can follow original FASTQ basenames rather than sample_id.

The module runs FastQC with allocated threads. Standard resource request is 4 CPUs, 8 GB and 2 h per task. Parameters include samples_master, output folder and resource settings; fallback raw-directory patterns are for advanced use.

**Interpretation:** inspect base-quality profiles, adapter content, overrepresented sequences, GC distribution and N content. A warning alone is not a sample rejection rule. Compare like libraries and inspect the actual report; this module reports problems but does not trim reads or implement an automatic biological pass/fail gate.

## fastp — paired read preprocessing

**Input:** original paired FASTQs selected by the master. **Output in `RUN/fastp_output/`:** `<sample>_R1.fastp.trimmed.fastq.gz`, matching R2, `<sample>.fastp.html` and `<sample>.fastp.json`.

The actual command specifies `-i/-I`, `-o/-O`, `-j`, `-h` and `-w`. It does not pass custom adapter sequences, cut-tail options or custom quality/length thresholds; remaining behavior follows the configured fastp executable's defaults. Standard resources: 4 CPUs, 8 GB, 2 h.

**Interpretation:** compare input/output read totals, adapter trimming, quality profiles and retained lengths. Investigate unusually large losses and persistent adapter signals; do not assume the wrapper enables every available fastp trimming option. JSON files feed downstream QC summaries. Trimmed FASTQs are published results and can occupy substantial space.

## BWA + SAMtools — alignment and sorting

**Input:** this run's paired fastp outputs plus the configured FASTA/index. **Output in `RUN/bwa_output/`:** `<sample>.sorted.bam`, its `.bai`, and `<sample>.bam.stat` from flagstat. SAM and unsorted BAM are not published; the temporary BAM is removed by the task.

Index command: `bwa index -a bwtsw`. Mapping command: `bwa mem -t <cpus> -M`, piped into SAMtools BAM conversion, then flagstat, sorting and indexing. `-M` requests marking shorter split hits as secondary. Mapping requests 8 CPUs, 32 GB, 12 h; indexing requests 8 CPUs, 16 GB, 2 h in the HPC profile.

The launcher creates indexes under RUN/99_intermediate/reference/bwa, or links an existing complete matching primary_bwa index. It does not build into the external reference directory.

**Interpretation:** review mapped and properly paired counts alongside library quality and reference choice. Counts are alignment/read records, not automatically fragment counts; flag categories can overlap. A high mapping rate alone does not establish ChIP enrichment. Inspect the sorted BAM in a genome browser when investigating unusual regions.

## Picard — duplicate removal and BAM QC

**Input:** `RUN/bwa_output/*.sorted.bam`. **Output:** `RUN/picard_output/` contains `*.dedup.bam`, `.bai`, `*.dedup.metrics.txt`, `*.picard_qc.stats.tsv`, insert-size TXT/PDF and alignment-summary TXT. Names can retain `.sorted` from the upstream BAM basename; do not assume they equal sample_id exactly.

Standard `remove_duplicates=true` runs MarkDuplicates with REMOVE_DUPLICATES=true, ASSUME_SORTED=true, VALIDATION_STRINGENCY=SILENT and MAX_RECORDS_IN_RAM=250000, followed by indexing. Mark-only mode exists in advanced configuration. Duplicate processes request 4 CPUs, 40 GB, 24 h; other QC processes default to 4 CPUs, 16 GB, 8 h.

**Interpretation:** inspect duplicate fraction, retained mapped reads, insert-size distribution and alignment metrics together. Loss of duplicates changes usable depth. Picard PERCENT_DUPLICATION is a fraction; the custom QC table converts it to a percentage. This is coordinate-based duplicate handling, not UMI-aware molecule deduplication. Insert-size outliers deserve review in the context of the library protocol.

## chipfilter — MAPQ filtering and mitochondrial statistics

**Input:** Picard dedup BAMs, with markdup fallback if dedup files are absent. **Output:** `RUN/chipfilter_output/*.nomulti.bam`, `.bai`, and `*.chipfilter.stats.tsv`. Upstream suffixes may be retained in the filenames.

The filter command is `samtools view -b -q 24`, followed by indexing. No mitochondrial exclusion or additional SAM flag filter is applied by this command. The name “nomulti” denotes this MAPQ-filtered output, not a proof every record is uniquely mapped.

The QC process counts `nomulti_reads` using `samtools view -c -F 260`, gets chrM/MT mapped counts from idxstats, and reports `clean_reads_estimated = nomulti_reads - mito_reads`, plus pct_mito. These are estimates based on different counting operations; clean_reads_estimated is not the size of a separately written mitochondrial-depleted BAM. Both processes request 2 CPUs, 8 GB, 4 h.

**Interpretation:** inspect read retention and mitochondrial burden. Mitochondrial alignments remain in the BAM sent downstream. Do not describe the current pipeline as mitochondrial-read removal or treat estimated usable reads as a directly counted fragment total.

## MACS3 — independent peak calling at two thresholds

**Input:** each sample's filtered treatment BAM resolved from this run, paired through macs3_samplesheet with the shared Input BAM. The explicit MACS3 sheet takes precedence over master-based control resolution.

| Parameter | Standard value / effect |
|---|---|
| seq | paired, selects `-f BAMPE` |
| genome_size | mm |
| q thresholds | 0.05 and 0.01, separate calls per sample |
| keep_dup | all; duplicate handling already occurs upstream |
| call_summits | true |
| write_bedgraph | false; pileup/control bedGraphs are not expected by default |
| peak_type | empty, narrow-peak mode |
| peak blacklist | empty in standard env, therefore not applied |

HPC peak calling requests 4 CPUs, 16 GB, 12 h. Output directories are `RUN/macs3_output/consensus_q0.05/` and `RUN/macs3_output/strict_q0.01/`, with `<sample>_peaks.narrowPeak`, `<sample>_peaks.xls` and optional summits BED. “consensus” is a historical branch label only. IDR q=0.1 is disabled.

**Interpretation:** check both branches for every sample, inspect peak intervals and enrichment against Input, and compare the two thresholds. q=0.01 is more stringent; do not equate every called peak with a validated biological site. narrowPeak contains genomic intervals and signal/significance fields; it is not a gene-annotation table. No replicate reproducibility claim is made.

Optional blacklist filtering uses BEDTools intersect `-v -f 0.5` on peak intervals when a BED is supplied. It is disabled here. If enabled, it alters peak files, not upstream BAMs, and does not automatically recompute MACS3 XLS or summits. Do not expect a blacklist report for this standard run.

## bamCoverage — normalized signal tracks

**Input:** run-local filtered BAMs plus their indexes. **Output:** `RUN/bamcoverage_output/bigwig/<sample>.bw` and `<sample>.bamCoverage.log.txt`.

| Parameter | Configured value |
|---|---|
| binSize | 20 |
| normalizeUsing | RPGC |
| effectiveGenomeSize | 2468088461 |
| extendReads | 150 |
| centerReads | true |
| ignoreDuplicates | true |
| smoothLength | 60 |
| minMappingQuality | 10 |
| blacklist / samFlagExclude / scaleFactor | unset |

These are literal wrapper settings; fragment extension behavior depends on paired-read handling in deepTools. Upstream MAPQ 24 filtering has already occurred; the track's MAPQ 10 cannot restore discarded reads. Resources: 14 CPUs, 16 GB, 4 h.

**Interpretation:** view tracks with peaks using the matching genome assembly and consistent display scales. RPGC tracks describe normalized ChIP coverage, not ChIP-minus-Input or fold enrichment over Input. Shared Input is used by MACS3, not subtracted by bamCoverage. Smoothing/binning affects visible peak shape. The effective genome size must be reviewed for other references or normalization policies.

## MultiQC — consolidated QC report

**Input:** module result directories scanned under this run; optional extra scan roots/custom YAML are advanced settings. **Output:** `RUN/multiqc_output/multiqc_report.html` and report data emitted by MultiQC. Standard title is ChIP-seq Pipeline Summary. Resources: 2 CPUs, 8 GB, 2 h.

**Interpretation:** compare samples across FastQC, fastp, alignment and duplicate metrics. Parser coverage determines which reports appear. Missing metrics can indicate missing/unsupported source reports, not zero values. MultiQC does not automatically reject samples or certify that every analysis succeeded. The external Input QC is separately captured through the delivery manifest; it is not automatically added to the ordinary scan simply because the manifest exists.

## Result delivery — sample and shared-control summaries

**Input:** master metadata, module QC/results, and shared_control_manifest. **Output:** `RUN/result_delivery_output/final_delivery_<tag>/08_Summary/`, with sample QC tables, shared-control summaries, dictionaries and notes in TSV/CSV/Markdown forms. The tag defaults through launcher/module settings when not supplied. Resources: 1 CPU, 8 GB, 2 h.

`DELIVERY_LEVEL=lean` is a summary package. Save MACS3 and bigWig outputs separately. shared_control_id is populated from the manifest; the Input QC is read from its previous fastp/bwa/picard/chipfilter folders. This does not rerun or independently validate the control.

Peak counts at q=0.05 and q=0.01 should correspond to the relevant output files. FRiP, IDR and universe-related fields/tables may be NA, empty or unavailable because those analyses are disabled. Do not interpret absent information as a measured zero. Review dictionaries and source reports when a value is surprising. The delivery module is not an automatic biological acceptance gate.

## Review, recovery and cleanup

1. Confirm launcher and enabled modules completed; inspect the latest attempt, not an older failed log.
2. Confirm every selected sample has paired QC, filtered BAM/index, two MACS3 profiles and a bigWig.
3. Review mapping, duplication, retained reads, mitochondrial burden and sample-specific peak/track patterns. Record exclusions or caveats; no universal QC threshold is imposed by this wrapper.
4. Back up required module outputs and 02_run_record. The lean summary alone is insufficient for later peak/track use.
5. Only after completion and backup, remove that run's 99_intermediate if cached resume is no longer required. Preserve shared_input, original FASTQs, references and code. Published trimmed FASTQ/BAM files still consume space.

For failure recovery retain the same input/code/RUN_ID with RESUME=true and RESET_OUTPUTS=false. Do not run concurrently. New inputs, reference or q thresholds require a new run ID because some modules skip already-published outputs independently of Nextflow resume. Never remove a lock until launcher and compute tasks are confirmed stopped.

## Maintainer notes and boundaries

Full options remain in ../archive/configs/pipeline.advanced.env.example. They need experimental-design review: consensus automatic mode expects two replicates per condition, IDR selects the first two, and heatmap currently depends on DiffBind. These branches are outside standard handoff operation.

The HPC image filenames are not immutable pins; resource overrides and source edits can change behavior. See [validation scope](../tests/README.md). This manual records actual wrapper settings and explicitly identifies version gaps; final deployment should preserve executable/image provenance alongside source records.

Historical walkthroughs are under ../archive/legacy_docs/walkthroughs. Extracted presentation material is in [../archive/presentation/ORAL_PRESENTATION_NOTES.md](../archive/presentation/ORAL_PRESENTATION_NOTES.md), separate from operating instructions.
