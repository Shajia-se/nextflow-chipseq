# Nextflow ChIP-seq Pipeline 使用手册

这份手册写给想使用 `nextflow-chipseq` 的人，尤其是对 Nextflow 不熟悉、但需要把 ChIP-seq 数据从 FASTQ 跑到 peak calling、QC、annotation 和交付结果的人。

本文只描述当前 pipeline 的设计和使用方式。不代表已经在你的目标 HPC 上完成真实运行测试。交付前仍然需要在目标环境上做小规模测试和完整运行验证。

## 1. Pipeline 总览

`nextflow-chipseq` 是一个 launcher。它本身不直接做分析，而是按顺序调用多个独立的 `nf-*` 模块。

默认顺序：

```text
1. nf-fastqc
2. nf-fastp
3. nf-bwa
4. nf-picard
5. nf-chipfilter
6. nf-macs3
7. nf-idr
8. nf-peak-consensus
9. nf-diffbind
10. nf-bamcoverage
11. nf-frip
12. nf-chipseeker
13. nf-homer
14. nf-deeptools-heatmap
15. nf-multiqc
16. nf-result-delivery
```

简单理解：

```text
FASTQ
  -> QC
  -> trimming
  -> alignment
  -> sorted/deduplicated BAM
  -> filtered BAM
  -> peaks
  -> reproducible/consensus peaks
  -> downstream QC and biological interpretation
  -> summary report and delivery folder
```

## 2. 使用者需要准备的文件

### 2.1 必须文件

| 文件 | 说明 |
| --- | --- |
| FASTQ R1/R2 | paired-end sequencing reads |
| `samples_master.csv` | 样本信息总表，最重要 |
| `pipeline.env` | 运行配置文件 |
| reference FASTA | BWA alignment 使用 |
| BWA index | 必须和 reference FASTA 匹配 |
| GTF | ChIPseeker annotation 使用 |

### 2.2 可选文件

| 文件 | 什么时候需要 |
| --- | --- |
| `macs3_samplesheet.csv` | input/control BAM 已经存在，或想手动指定 treatment/control BAM |
| `idr_pairs.csv` | 不想自动按 condition/replicate 配 IDR |
| `consensus_pairs.csv` | 不想自动做 consensus replicate pairing |
| `diffbind_samplesheet.csv` | 想用 DiffBind 官方 samplesheet 手动控制 |
| `frip_samplesheet.csv` | 想手动指定每个 BAM 和 peak 文件 |
| `motif_compare_sheet.csv` | 想做 HOMER motif compare |
| blacklist BED | 想对 MACS3 peaks 做 blacklist 过滤 |
| MultiQC config YAML | 想自定义 MultiQC 报告 |

默认推荐：先只填写 `samples_master.csv` 和 `pipeline.env`。除非你明确知道为什么需要手动表格，否则 optional sheets 留空。

## 3. 目录结构

推荐 pipeline 目录长这样：

```text
/path/to/pipelines/
  nextflow-chipseq/
    run_end2end.sh
    run_end2end_parallel_safe.sh
    pipeline.env.example
    pipeline.env
    samples_master.csv
    QUICK_START_CN.md
    MANUAL_CN.md
  nf-fastqc/
  nf-fastp/
  nf-bwa/
  nf-picard/
  nf-chipfilter/
  nf-macs3/
  nf-idr/
  nf-peak-consensus/
  nf-diffbind/
  nf-bamcoverage/
  nf-frip/
  nf-chipseeker/
  nf-homer/
  nf-deeptools-heatmap/
  nf-multiqc/
  nf-result-delivery/
```

`PIPELINES_ROOT` 应该指向：

```text
/path/to/pipelines
```

而不是：

```text
/path/to/pipelines/nextflow-chipseq
```

## 4. 配置文件 `pipeline.env`

先复制模板：

```bash
cd /path/to/pipelines/nextflow-chipseq
cp pipeline.env.example pipeline.env
```

然后编辑：

```bash
nano pipeline.env
```

### 4.1 基础设置

```bash
PROFILE=hpc
HPC_MAIL_USER=molendo.hpc@gmail.com
RESUME=true
PIPELINES_ROOT=/path/to/pipelines
OUTPUT_PROJECT_ROOT=/path/to/project_runs
RUN_ID=
RESET_OUTPUTS=false
START_FROM=
```

解释：

| 参数 | 说明 | 推荐 |
| --- | --- | --- |
| `PROFILE` | 运行环境。HPC 用 `hpc`，本地 Docker 用 `local` | `hpc` |
| `HPC_MAIL_USER` | Slurm 邮件通知 | `molendo.hpc@gmail.com` |
| `RESUME` | 是否启用 Nextflow resume | `true` |
| `PIPELINES_ROOT` | 所有模块所在目录 | 必填 |
| `OUTPUT_PROJECT_ROOT` | 结果保存的项目根目录 | 必填 |
| `RUN_ID` | 本次运行名字；留空自动生成时间戳 | 可留空 |
| `RESET_OUTPUTS` | 是否备份已有输出目录重新跑 | 通常 `false` |
| `START_FROM` | 从某个模块开始 | 第一次留空 |

如果不设置 `PIPELINES_ROOT`，当前 launcher 会默认使用 `nextflow-chipseq` 的父目录。也就是说，推荐目录结构下可以自动找到所有 `nf-*` 模块。但正式交付时仍建议显式填写 `PIPELINES_ROOT=/path/to/pipelines`。

### 4.2 样本表和参考文件

```bash
SAMPLES_MASTER=${PIPELINES_ROOT}/nextflow-chipseq/samples_master.csv

REFERENCE_FASTA=/path/to/genome.fa
GTF=/path/to/annotation.gtf
```

`REFERENCE_FASTA` 必须和 BWA index 对应。`GTF` 用于 peak annotation。

### 4.3 核心阈值

```bash
MAPQ_THRESHOLD=24
MACS3_QVALUE_IDR=0.1
MACS3_QVALUE_CONSENSUS=0.05
MACS3_QVALUE_STRICT=0.01
MACS3_PEAK_BLACKLIST_BED=
```

解释：

| 参数 | 用途 |
| --- | --- |
| `MAPQ_THRESHOLD` | BAM filtering 的 mapping quality 阈值 |
| `MACS3_QVALUE_IDR` | 给 IDR 分支用的较宽松 MACS3 peak cutoff |
| `MACS3_QVALUE_CONSENSUS` | consensus peak 分支 cutoff |
| `MACS3_QVALUE_STRICT` | strict peak 分支 cutoff，DiffBind/consensus 常用 |
| `MACS3_PEAK_BLACKLIST_BED` | 可选 blacklist BED；留空表示不使用 |

### 4.4 Optional sheets

```bash
MACS3_SAMPLESHEET=
IDR_PAIRS_CSV=
DIFFBIND_SAMPLESHEET=
FRIP_SAMPLESHEET=
HOMER_MOTIF_COMPARE_SHEET=
CONSENSUS_PAIRS_CSV=
```

推荐第一次运行全部留空。pipeline 会尽量从 `samples_master.csv` 自动生成下游需要的 pairing。

如果某个 optional sheet 变量不是空值，launcher 会在启动前检查该文件是否存在。路径写错会立即报错，不会静默退回自动模式。

### 4.5 模块开关

```bash
RUN_FASTQC=true
RUN_FASTP=true
RUN_BWA=true
RUN_PICARD=true
RUN_CHIPFILTER=true
RUN_MACS3=true
RUN_IDR=true
RUN_PEAK_CONSENSUS=true
RUN_DIFFBIND=true
RUN_BAMCOVERAGE=true
RUN_FRIP=true
RUN_CHIPSEEKER=true
RUN_HOMER=true
RUN_DEEPTOOLS_HEATMAP=true
RUN_MULTIQC=true
RUN_RESULT_DELIVERY=true
```

建议：

- 有 biological replicates：可以打开 `RUN_IDR=true`, `RUN_DIFFBIND=true`。
- 没有 replicates：建议 `RUN_IDR=false`, `RUN_DIFFBIND=false`, `RUN_DEEPTOOLS_HEATMAP=false`。
- 只想得到 BAM 和 MACS3 peaks：保留到 `RUN_MACS3=true`，把多数 downstream 设为 `false`。
- 最终交付建议保留 `RUN_MULTIQC=true` 和 `RUN_RESULT_DELIVERY=true`。

当前 `RUN_DEEPTOOLS_HEATMAP=true` 依赖 `RUN_DIFFBIND=true`，因为 heatmap 使用 DiffBind 输出的 gain/loss BED 文件。没有 DiffBind 结果时请关闭 deepTools heatmap。

## 5. 样本总表 `samples_master.csv`

`samples_master.csv` 是最重要的输入文件。它告诉 pipeline：

- 哪些 FASTQ 属于哪个样本。
- 哪些样本是 ChIP/IP，哪些是 input/control。
- 哪些 ChIP 样本使用哪个 input/control。
- 哪些样本用于 IDR 和 DiffBind。
- 哪些样本暂时启用或禁用。

### 5.1 表头

必须使用：

```csv
sample_id,condition,replicate,library_type,fastq_r1,fastq_r2,is_control,control_id,use_for_idr,use_for_diffbind,enabled
```

### 5.2 列解释

| 列 | 必填 | 例子 | 说明 |
| --- | --- | --- | --- |
| `sample_id` | yes | `WT_rep1` | 样本唯一 ID，不能重复 |
| `condition` | yes | `WT` | 生物组别 |
| `replicate` | yes | `1` | 生物重复编号 |
| `library_type` | yes | `chip` 或 `input` | 样本类型 |
| `fastq_r1` | yes | `/data/a_R1.fastq.gz` | R1 FASTQ 绝对路径 |
| `fastq_r2` | yes | `/data/a_R2.fastq.gz` | R2 FASTQ 绝对路径 |
| `is_control` | yes | `true` / `false` | 是否 input/control |
| `control_id` | chip 行建议必填 | `Input_1` | 对应 input/control 的 `sample_id` |
| `use_for_idr` | yes | `true` / `false` | 是否参与 IDR |
| `use_for_diffbind` | yes | `true` / `false` | 是否参与 DiffBind |
| `enabled` | yes | `true` / `false` | 是否启用该行 |

### 5.3 ChIP 行怎么填

```csv
WT_rep1,WT,1,chip,/data/WT_rep1_R1.fastq.gz,/data/WT_rep1_R2.fastq.gz,false,Input_1,true,true,true
```

规则：

- `library_type=chip`
- `is_control=false`
- `control_id` 填 input/control 的 `sample_id`
- 如果有 replicates，`use_for_idr=true`
- 如果做 DiffBind，`use_for_diffbind=true`

### 5.4 Input/control 行怎么填

```csv
Input_1,Input,1,input,/data/Input_1_R1.fastq.gz,/data/Input_1_R2.fastq.gz,true,,false,false,true
```

规则：

- `library_type=input`
- `is_control=true`
- `control_id` 留空
- `use_for_idr=false`
- `use_for_diffbind=false`

### 5.5 完整例子

```csv
sample_id,condition,replicate,library_type,fastq_r1,fastq_r2,is_control,control_id,use_for_idr,use_for_diffbind,enabled
WT_rep1,WT,1,chip,/data/WT_rep1_R1.fastq.gz,/data/WT_rep1_R2.fastq.gz,false,Input_1,true,true,true
WT_rep2,WT,2,chip,/data/WT_rep2_R1.fastq.gz,/data/WT_rep2_R2.fastq.gz,false,Input_1,true,true,true
KO_rep1,KO,1,chip,/data/KO_rep1_R1.fastq.gz,/data/KO_rep1_R2.fastq.gz,false,Input_1,true,true,true
KO_rep2,KO,2,chip,/data/KO_rep2_R1.fastq.gz,/data/KO_rep2_R2.fastq.gz,false,Input_1,true,true,true
Input_1,Input,1,input,/data/Input_1_R1.fastq.gz,/data/Input_1_R2.fastq.gz,true,,false,false,true
```

## 6. Treatment 和 Input/Control 怎么处理

MACS3 peak calling 的核心是：

```text
macs3 callpeak -t treatment.bam -c control.bam
```

在这个 pipeline 里：

- treatment BAM 是 ChIP/IP 样本经过 `nf-chipfilter` 后的 `*.nomulti.bam`。
- control BAM 是 input/control 样本，也应该是过滤后的 BAM。

### 6.1 input/control 也从 FASTQ 跑

这是最标准、最简单的方式。把 input/control 作为一行写进 `samples_master.csv`。

ChIP 行：

```csv
WT_rep1,WT,1,chip,/data/WT_rep1_R1.fastq.gz,/data/WT_rep1_R2.fastq.gz,false,Input_1,true,true,true
```

Input 行：

```csv
Input_1,Input,1,input,/data/Input_1_R1.fastq.gz,/data/Input_1_R2.fastq.gz,true,,false,false,true
```

pipeline 会先把 input/control FASTQ 也跑到 `chipfilter_output`，然后 MACS3 自动找到它。

### 6.2 input/control BAM 已经存在

如果 input/control BAM 已经存在，不想重新跑 FASTQ，需要写 `macs3_samplesheet.csv`。

在 `pipeline.env` 中：

```bash
MACS3_SAMPLESHEET=/path/to/macs3_samplesheet.csv
```

表格：

```csv
sample_id,treatment_bam,control_bam
WT_rep1,,/path/to/existing_input.nomulti.bam
WT_rep2,,/path/to/existing_input.nomulti.bam
KO_rep1,,/path/to/existing_input.nomulti.bam
KO_rep2,,/path/to/existing_input.nomulti.bam
```

`treatment_bam` 留空时，pipeline 会从当前 run 的 `chipfilter_output` 找：

```text
<sample_id>*.nomulti.bam
```

这种方式适合已有 shared input/control 的项目。

注意：existing input/control BAM 必须和 ChIP BAM 使用相同 genome build，并且 chromosome naming 一致，比如不能一个是 `chr1`，另一个是 `1`。

## 7. Optional sheets 什么时候用

### 7.1 `IDR_PAIRS_CSV`

默认情况下，IDR 会从 `samples_master.csv` 中按 `condition` 和 `replicate` 自动配对。

如果你想手动指定哪两个 peak 文件做 IDR，使用：

```bash
IDR_PAIRS_CSV=/path/to/idr_pairs.csv
```

格式：

```csv
pair_name,rep1_peaks,rep2_peaks
WT,/path/to/WT_rep1_peaks.narrowPeak,/path/to/WT_rep2_peaks.narrowPeak
KO,/path/to/KO_rep1_peaks.narrowPeak,/path/to/KO_rep2_peaks.narrowPeak
```

### 7.2 `CONSENSUS_PAIRS_CSV`

如果不想自动从 replicates 生成 consensus peaks，可以手动指定：

```bash
CONSENSUS_PAIRS_CSV=/path/to/consensus_pairs.csv
```

具体列名请以 `nf-peak-consensus` README 为准。

### 7.3 `DIFFBIND_SAMPLESHEET`

如果想完全控制 DiffBind 输入：

```bash
DIFFBIND_SAMPLESHEET=/path/to/diffbind_samplesheet.csv
```

常见列：

```csv
SampleID,Condition,Replicate,bamReads,Peaks,PeakCaller
```

自动模式更适合第一次使用；手动 DiffBind samplesheet 更适合复杂实验设计。

### 7.4 `FRIP_SAMPLESHEET`

如果想手动指定每个 BAM 用哪个 peak set 计算 FRiP：

```bash
FRIP_SAMPLESHEET=/path/to/frip_samplesheet.csv
```

格式：

```csv
sample_id,bam,peaks
WT_rep1,/path/to/WT_rep1.nomulti.bam,/path/to/WT_idr.sorted.narrowPeak
```

### 7.5 `HOMER_MOTIF_COMPARE_SHEET`

如果要做 motif compare：

```bash
HOMER_MOTIF_COMPARE_SHEET=/path/to/motif_compare_sheet.csv
```

格式：

```csv
group_name,target_bed,background_bed
KO_unique_vs_WT_bg,/path/to/target.bed,/path/to/background.bed
```

### 7.6 Optional sheet 路径检查

只要在 `pipeline.env` 里填写了 optional sheet 或 optional file 路径，例如：

```bash
MACS3_SAMPLESHEET=/path/to/macs3_samplesheet.csv
IDR_PAIRS_CSV=/path/to/idr_pairs.csv
MACS3_PEAK_BLACKLIST_BED=/path/to/blacklist.bed
```

这些文件就必须存在。否则 launcher 会在任何 Nextflow 模块启动前停止。

## 8. Peak sources 怎么理解

下游模块可以使用不同来源的 peaks：

```bash
FRIP_PEAK_SOURCES=
CHIPSEEKER_PEAK_SOURCES=
HOMER_PEAK_SOURCES=
```

如果留空，launcher 会根据上游模块开关自动选择。

常见值：

```text
idr
consensus_q0.01
consensus_q0.05
diffbind
```

例子：

```bash
FRIP_PEAK_SOURCES=idr,consensus_q0.01,consensus_q0.05
CHIPSEEKER_PEAK_SOURCES=idr,consensus_q0.01,consensus_q0.05,diffbind
HOMER_PEAK_SOURCES=idr,consensus_q0.01
```

如果某个上游模块没有运行，不要在这里选择它的 peak source。

## 9. 如何启动 pipeline

### 9.1 顺序运行

```bash
cd /path/to/pipelines/nextflow-chipseq
bash run_end2end.sh pipeline.env
```

顺序运行更容易排查问题，适合第一次测试。

### 9.2 并行安全运行

```bash
bash run_end2end_parallel_safe.sh pipeline.env
```

并行版本会在依赖关系允许的地方同时启动多个模块，适合环境已经验证过之后使用。

## 10. 如何续跑

推荐始终保持：

```bash
RESUME=true
```

如果某一步失败，修正问题后重新运行同一条命令即可。

如果想从某一步开始：

```bash
START_FROM=macs3
```

可选值：

```text
fastqc
fastp
bwa
picard
chipfilter
macs3
idr
peak_consensus
diffbind
bamcoverage
frip
chipseeker
homer
deeptools
multiqc
result_delivery
```

注意：`START_FROM` 不会凭空生成上游结果。比如从 `macs3` 开始，必须已经有 `chipfilter_output`。

## 11. 输出目录

输出根目录：

```bash
${OUTPUT_PROJECT_ROOT}/${RUN_ID}/
```

如果 `RUN_ID` 留空，launcher 会自动生成类似：

```text
20260811_153000
```

典型输出：

```text
fastqc_output/
fastp_output/
bwa_output/
picard_output/
chipfilter_output/
macs3_output/
idr_output/
peak_consensus_output/
diffbind_output/
bamcoverage_output/
frip_output/
chipseeker_output/
homer_output/
deeptools_heatmap_output/
multiqc_output/
result_delivery_output/
logs/
```

### 11.1 交付时重点看什么

| 目录 | 内容 |
| --- | --- |
| `result_delivery_output/` | 整理后的交付结果 |
| `multiqc_output/` | 总 QC 报告 |
| `chipfilter_output/` | 最终过滤 BAM/BAI/QC |
| `macs3_output/` | per-sample peaks |
| `idr_output/` | IDR reproducible peaks |
| `peak_consensus_output/` | consensus peaks |
| `diffbind_output/` | differential binding 结果 |
| `bamcoverage_output/` | BigWig tracks |
| `chipseeker_output/` | peak annotation |
| `homer_output/` | motif analysis |

设计原则：保留最终 BAM/BAI/QC 和关键 downstream 结果，不依赖大型 SAM 中间文件作为交付结果。

## 12. 常见使用场景

### 12.1 标准 replicate ChIP-seq

有两个 condition，每组至少两个 replicate，一个或多个 input/control。

推荐：

```bash
RUN_IDR=true
RUN_PEAK_CONSENSUS=true
RUN_DIFFBIND=true
RUN_FRIP=true
RUN_CHIPSEEKER=true
RUN_MULTIQC=true
RUN_RESULT_DELIVERY=true
```

### 12.2 没有 replicates

推荐关闭：

```bash
RUN_IDR=false
RUN_DIFFBIND=false
RUN_DEEPTOOLS_HEATMAP=false
```

保留：

```bash
RUN_MACS3=true
RUN_BAMCOVERAGE=true
RUN_CHIPSEEKER=true
RUN_MULTIQC=true
RUN_RESULT_DELIVERY=true
```

### 12.3 已有 input/control BAM

使用：

```bash
MACS3_SAMPLESHEET=/path/to/macs3_samplesheet.csv
```

不要把不存在 FASTQ 的 input/control 强行写进 `samples_master.csv` 让它从头跑。

### 12.4 只想跑到 peak calling

可以关闭下游模块：

```bash
RUN_IDR=false
RUN_PEAK_CONSENSUS=false
RUN_DIFFBIND=false
RUN_BAMCOVERAGE=false
RUN_FRIP=false
RUN_CHIPSEEKER=false
RUN_HOMER=false
RUN_DEEPTOOLS_HEATMAP=false
RUN_MULTIQC=true
RUN_RESULT_DELIVERY=true
```

## 13. 运行前检查清单

### 文件检查

- `pipeline.env` 存在。
- `samples_master.csv` 存在。
- 所有 FASTQ 路径存在。
- `REFERENCE_FASTA` 存在。
- BWA index 存在。
- `GTF` 存在。
- container `.sif` 文件在 HPC 上存在。

### 表格检查

- `sample_id` 没有重复。
- ChIP 行 `control_id` 能匹配 input/control 行。
- input/control 行 `is_control=true`。
- ChIP 行 `is_control=false`。
- boolean 值使用 `true` / `false`。
- 每个 condition 的 replicate 编号合理。
- 不想运行的样本设置 `enabled=false`。

### 分析设计检查

- IDR 至少需要同一 condition 内两个 biological replicates。
- DiffBind 需要可比较的 conditions 和 replicates。
- shared input/control BAM 必须和 treatment BAM 的 genome build 一致。
- blacklist BED 的 genome build 必须和 reference 一致。
- 如果 `RUN_DIFFBIND=false`，同时设置 `RUN_DEEPTOOLS_HEATMAP=false`。
- 如果填写了 optional sheet 或 blacklist BED，文件必须存在。

## 14. 常见错误和解决方向

### 14.1 找不到 FASTQ

检查 `samples_master.csv`：

- 是否使用绝对路径。
- 文件名是否写错。
- HPC 上是否能访问该路径。

### 14.2 MACS3 找不到 control

检查：

- ChIP 行 `control_id` 是否匹配 input/control 的 `sample_id`。
- input/control 行是否 `enabled=true`。
- input/control 是否已经产生 `*.nomulti.bam`。
- 如果使用现成 BAM，是否正确填写 `MACS3_SAMPLESHEET`。

### 14.3 IDR 没有输出

检查：

- 每个 condition 是否至少两个 ChIP replicate。
- `use_for_idr=true`。
- `RUN_IDR=true`。
- MACS3 `idr_q0.1` 分支是否产生 peak 文件。

### 14.4 DiffBind 没有 contrast

可能原因：

- 每组 replicate 不足。
- 只有一个 condition。
- `use_for_diffbind=false`。
- `condition` 或 `replicate` 填写不一致。

### 14.5 ChIPseeker 或 HOMER 找不到 peaks

检查：

- `CHIPSEEKER_PEAK_SOURCES` 或 `HOMER_PEAK_SOURCES` 是否选择了没有运行的上游结果。
- `RUN_IDR`, `RUN_PEAK_CONSENSUS`, `RUN_DIFFBIND` 是否和 peak sources 匹配。

### 14.6 deepTools heatmap 提前报错

如果看到：

```text
RUN_DEEPTOOLS_HEATMAP=true requires RUN_DIFFBIND=true
```

说明当前配置打开了 deepTools heatmap，但关闭了 DiffBind。解决方式：

```bash
RUN_DIFFBIND=true
```

或者：

```bash
RUN_DEEPTOOLS_HEATMAP=false
```

## 15. 交付建议

交付前建议至少保存：

```text
pipeline.env
samples_master.csv
multiqc_output/
result_delivery_output/
logs/
```

如果空间允许，建议同时保留：

```text
chipfilter_output/*.nomulti.bam
chipfilter_output/*.nomulti.bam.bai
macs3_output/
idr_output/
peak_consensus_output/
bamcoverage_output/
chipseeker_output/
diffbind_output/
```

不建议把大型 SAM 中间文件作为交付重点。当前 pipeline 设计上更偏向保留最终 BAM/BAI/QC 和核心 downstream 结果。

## 16. 对维护者的说明

- 架构决策应记录在 `nextflow-chipseq` 总览或 manual 中。
- 单个模块应能独立测试。
- `main.nf`、`nextflow.config`、`configs/slurm.config` 的参数接口需要保持一致。
- Wrapper 中传给模块的参数名必须和模块 README/main.nf 对齐。
- 单次报错解决后，应在 issue/log 或维护记录里归档，不要把临时项目路径写成默认值。
- 不能在未实际运行验证的情况下写“pipeline tested successfully”。
- 不要把真实个人运行文件作为通用交付文件提交，例如 `pipeline.env`、项目特定 env、`.DS_Store`、项目特定 merge 脚本。通用交付应使用 `pipeline.env.example` 和模板文件。

## 17. 最小命令总结

```bash
cd /path/to/pipelines/nextflow-chipseq
cp pipeline.env.example pipeline.env
cp samples_master_template.csv samples_master.csv

# edit pipeline.env and samples_master.csv

bash run_end2end.sh pipeline.env
```

如果失败，修正后：

```bash
bash run_end2end.sh pipeline.env
```

如果要从某一步继续：

```bash
# edit pipeline.env
START_FROM=macs3
RESUME=true

bash run_end2end.sh pipeline.env
```
