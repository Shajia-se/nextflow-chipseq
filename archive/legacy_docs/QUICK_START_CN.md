> Archived, superseded instructions. Use [current quick start](../../quick-start.md).

# 新样品快速开始

每次运行全部放在 `chip_runs/日期_运行人/`，不用再建立 project_A/runs_output 等层级。

## 1. 建立本次运行

在 nextflow-chipseq 仓库内：

```bash
python3 scripts/new_run.py 20260911_shan
```

默认生成到相邻的 `../chip_runs/20260911_shan/`。名字换成实际日期和运行人；同一天多次运行加 `_test1`、`_run2` 等后缀。脚本拒绝覆盖已有目录。

## 2. 只编辑两个文件

- `samples_master.csv`：替换全部示例行，写实际 paired-end FASTQ 绝对路径；ChIP 和 Input 都占一行；control_id 对应 Input 的 sample_id。原始 FASTQ 不需要搬动。
- `pipeline.env`：填写参考 FASTA/GTF 绝对路径、接收通知的邮箱和模块开关。保留生成好的 PIPELINES_ROOT、CHIP_RUNS_ROOT、RUN_ID、SAMPLES_MASTER；设置 RESET_OUTPUTS=false。

参考文件和样本表使用绝对路径；不要在 CSV 路径或名字里使用逗号、空格或 shell 特殊字符。设置了可选样本表路径就必须提供真实存在的文件。外部 shared Input BAM 场景仍需要显式 MACS3 样本表和对应挂载。

上游首次验证启用 FASTQC、FASTP、BWA、PICARD、CHIPFILTER、MULTIQC，关闭其他 RUN_* 开关。正式下游根据真实 Input/重复设计启用；简化模板固定运行上游、MACS3、bigWig、MultiQC 和交付；完整模块开关见 pipeline.advanced.env.example。

## 3. 运行

HPC：

```bash
sbatch ../chip_runs/20260911_shan/submit.sh
```

普通终端直接启动：

```bash
bash run_end2end_parallel_safe.sh /绝对路径/chip_runs/20260911_shan/pipeline.env
```

本地运行设置 PROFILE=local；须有可用 Docker 镜像和合适的资源设置，可通过 NEXTFLOW_CONFIG 指定绝对路径的额外 Nextflow config。启动文件仍是同一个。

## 4. 拿结果、清理

各 `*_output/` 直接在本次 run 下。`02_run_record/` 按启动次数保存配置、样本表、版本、命令和日志。查看最新启动的 run.json，以及其 logs/ 下模块 status.json 和 console.log。

确认结果完整、保存到最终位置后，可以删除整个 `99_intermediate/` 文件夹。保留结果和 `02_run_record/`。失败或未完成不要删除；删除后不能依赖原缓存恢复。

恢复时保持同一个 RUN_ID 和 RESUME=true；修改输入或分析参数时使用新 RUN_ID。新版本拒绝旧 OUTPUT_PROJECT_ROOT；不会自动搬动旧 work 或旧结果。不要在 nf-* repo 内直接执行 nextflow run 来绕过统一目录管理。
