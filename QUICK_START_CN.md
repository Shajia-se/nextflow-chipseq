# Nextflow ChIP-seq Pipeline 快速开始

这份文档给第一次使用本 pipeline 的人看。目标是：知道需要准备哪些文件、填写哪些表格、修改哪些配置，然后用一条命令启动流程。

如果你需要完整解释，请看：

```text
MANUAL_CN.md
```

## 1. 这个 Pipeline 做什么

默认流程：

```text
FastQC
  -> fastp trimming
  -> BWA alignment
  -> Picard BAM processing/QC
  -> MAPQ filtering
  -> MACS3 peak calling
  -> IDR / consensus peaks
  -> FRiP / BigWig / annotation / motif / heatmap / DiffBind
  -> MultiQC
  -> result delivery
```

核心输入是 paired-end FASTQ 文件、参考基因组 FASTA、GTF 注释文件、样本信息表 `samples_master.csv`。

## 2. 使用前需要准备什么

### 必须准备

1. FASTQ 文件

```text
sample_R1.fastq.gz
sample_R2.fastq.gz
```

2. 参考基因组 FASTA

```text
/path/to/genome.fa
```

3. GTF 注释文件

```text
/path/to/annotation.gtf
```

4. 样本信息表

```text
samples_master.csv
```

5. pipeline 配置文件

```text
pipeline.env
```

### HPC 环境需要已有

- Nextflow
- Slurm
- Singularity
- 各模块 `configs/slurm.config` 里写到的 `.sif` container image
- BWA index 已经为 `REFERENCE_FASTA` 建好

如果这些不确定，先不要承诺 pipeline 已经可运行；需要在目标 HPC 上做真实测试。

## 3. 第一步：复制配置文件

进入 `nextflow-chipseq`：

```bash
cd /path/to/pipelines/nextflow-chipseq
cp pipeline.env.example pipeline.env
```

然后编辑：

```bash
nano pipeline.env
```

## 4. 第二步：填写 `pipeline.env`

最重要的是这些：

```bash
PROFILE=hpc
HPC_MAIL_USER=molendo.hpc@gmail.com
PIPELINES_ROOT=/path/to/pipelines
OUTPUT_PROJECT_ROOT=/path/to/project_runs
SAMPLES_MASTER=/path/to/pipelines/nextflow-chipseq/samples_master.csv
REFERENCE_FASTA=/path/to/genome.fa
GTF=/path/to/annotation.gtf
```

字段解释：

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `PROFILE` | yes | HPC 通常用 `hpc`；本地 Docker 测试用 `local` |
| `HPC_MAIL_USER` | yes | Slurm 任务完成/失败通知邮箱 |
| `PIPELINES_ROOT` | yes | 所有 `nf-*` 模块所在目录 |
| `OUTPUT_PROJECT_ROOT` | yes | 每次运行结果保存在哪里 |
| `RUN_ID` | no | 留空会自动生成时间戳；也可手动写项目名 |
| `SAMPLES_MASTER` | yes | 样本信息总表 |
| `REFERENCE_FASTA` | yes | BWA alignment 使用的参考基因组 |
| `GTF` | yes | ChIPseeker/enrichment 注释使用 |
| `RESUME` | no | 推荐 `true`，失败后可续跑 |
| `START_FROM` | no | 从某一步开始，例如 `picard` |

推荐第一次运行保持：

```bash
RESUME=true
RESET_OUTPUTS=false
START_FROM=
```

## 5. 第三步：填写 `samples_master.csv`

可以从模板开始：

```bash
cp samples_master_template.csv samples_master.csv
```

然后编辑：

```bash
nano samples_master.csv
```

表头必须是：

```csv
sample_id,condition,replicate,library_type,fastq_r1,fastq_r2,is_control,control_id,use_for_idr,use_for_diffbind,enabled
```

### 每一列怎么填

| 列名 | 怎么填 |
| --- | --- |
| `sample_id` | 样本唯一名字，不能重复，例如 `WT_rep1` |
| `condition` | 生物组别，例如 `WT`, `KO`, `treated`, `control` |
| `replicate` | 生物重复编号，例如 `1`, `2`, `3` |
| `library_type` | ChIP 样本填 `chip`，input/control 填 `input` |
| `fastq_r1` | R1 FASTQ 的绝对路径 |
| `fastq_r2` | R2 FASTQ 的绝对路径 |
| `is_control` | input/control 行填 `true`，ChIP 行填 `false` |
| `control_id` | ChIP 行填写对应 input 的 `sample_id`；input 行留空 |
| `use_for_idr` | ChIP 重复用于 IDR 填 `true`；input 填 `false` |
| `use_for_diffbind` | ChIP 重复用于 DiffBind 填 `true`；input 填 `false` |
| `enabled` | 要运行填 `true`；临时排除样本填 `false` |

### 最常见例子：两个 condition，各两个 ChIP replicate，共用一个 input

```csv
sample_id,condition,replicate,library_type,fastq_r1,fastq_r2,is_control,control_id,use_for_idr,use_for_diffbind,enabled
WT_rep1,WT,1,chip,/data/WT_rep1_R1.fastq.gz,/data/WT_rep1_R2.fastq.gz,false,Input_1,true,true,true
WT_rep2,WT,2,chip,/data/WT_rep2_R1.fastq.gz,/data/WT_rep2_R2.fastq.gz,false,Input_1,true,true,true
KO_rep1,KO,1,chip,/data/KO_rep1_R1.fastq.gz,/data/KO_rep1_R2.fastq.gz,false,Input_1,true,true,true
KO_rep2,KO,2,chip,/data/KO_rep2_R1.fastq.gz,/data/KO_rep2_R2.fastq.gz,false,Input_1,true,true,true
Input_1,Input,1,input,/data/Input_1_R1.fastq.gz,/data/Input_1_R2.fastq.gz,true,,false,false,true
```

### 如果 input/control BAM 已经存在

如果 input/control 已经是现成 BAM，不想让它从 FASTQ 重新跑，普通 `samples_master.csv` 不够，需要额外填 `MACS3_SAMPLESHEET`。

在 `pipeline.env` 里设置：

```bash
MACS3_SAMPLESHEET=/path/to/macs3_samplesheet.csv
```

CSV 格式：

```csv
sample_id,treatment_bam,control_bam
WT_rep1,,/path/to/existing_input.nomulti.bam
WT_rep2,,/path/to/existing_input.nomulti.bam
```

这里 `treatment_bam` 留空表示从当前 pipeline 的 `chipfilter_output` 自动找 ChIP BAM；`control_bam` 指向已经存在的 input/control BAM。

## 6. 第四步：选择是否打开可选分析

默认大多数模块是打开的：

```bash
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

如果没有 biological replicates，建议先关掉：

```bash
RUN_IDR=false
RUN_DIFFBIND=false
RUN_DEEPTOOLS_HEATMAP=false
```

如果只想跑核心 peak calling，可保留：

```bash
RUN_FASTQC=true
RUN_FASTP=true
RUN_BWA=true
RUN_PICARD=true
RUN_CHIPFILTER=true
RUN_MACS3=true
RUN_MULTIQC=true
RUN_RESULT_DELIVERY=true
```

然后把其他下游模块设成 `false`。

## 7. 第五步：运行

顺序运行：

```bash
bash run_end2end.sh pipeline.env
```

并行安全版本：

```bash
bash run_end2end_parallel_safe.sh pipeline.env
```

第一次交付测试建议先用顺序版本，更容易看清楚报错位置。

## 8. 失败后怎么续跑

保持：

```bash
RESUME=true
```

如果想从某一步开始：

```bash
START_FROM=picard
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

然后重新运行：

```bash
bash run_end2end.sh pipeline.env
```

## 9. 输出在哪里

输出根目录：

```bash
${OUTPUT_PROJECT_ROOT}/${RUN_ID}/
```

常见结果：

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
```

最终交付通常优先看：

```text
result_delivery_output/
multiqc_output/
macs3_output/
idr_output/
peak_consensus_output/
diffbind_output/
bamcoverage_output/
chipseeker_output/
```

## 10. 运行前最后检查

运行前确认：

- `pipeline.env` 里的路径都是真实存在的。
- `samples_master.csv` 里所有 FASTQ 路径存在。
- `sample_id` 没有重复。
- `control_id` 能匹配某个 input/control 的 `sample_id`。
- boolean 值使用 `true` / `false`，不要混用 `TRUE` / `FALSE`。
- `REFERENCE_FASTA` 对应的 BWA index 已经存在。
- container `.sif` 路径在 HPC 上存在。

如果以上任何一点不确定，先做小样本测试，不要直接跑完整项目。
