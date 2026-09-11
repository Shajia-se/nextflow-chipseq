# ChIP-seq 交接操作手册

先按 [快速开始](QUICK_START_CN.md) 生成本次 run。代码由各 nf-* 仓库维护，分析数据归属 chip_runs/日期_运行人，不需要定期去各代码仓库寻找 work。

## 文件职责

| 文件/目录 | 内容 | 保留方式 |
|---|---|---|
| pipeline.env | 本次路径、参考、模块开关 | 随结果保存 |
| samples_master.csv | 样品、FASTQ、Input 配对、重复 | 随结果保存 |
| submit.sh | Slurm launcher；日志绝对路径在 run 内 | 随结果保存 |
| *_output/ | 各模块发布结果 | 验收/归档 |
| 02_run_record/<attempt>/ | 每次启动的 env、样本表、版本/代码差异、命令、日志、状态 | 随结果保存 |
| 99_intermediate/ | work、execution 缓存、临时文件、run-local BWA 索引 | 验收后可整体删除 |

各模块在 99_intermediate/execution/nf-* 中启动，main.nf 和默认 config 从原代码目录读取；work 明确写到 99_intermediate/work/nf-*。BWA 索引不会写回参考目录：发现完整匹配的既有索引时在 run 内链接，否则在 run 内构建。清理该目录不会删除外部索引目标。

## 参数

- PIPELINES_ROOT：包含 nextflow-chipseq 和全部 nf-* 仓库的父目录。
- CHIP_RUNS_ROOT：默认 PIPELINES_ROOT/chip_runs；可指定其他磁盘上名字为 chip_runs 的目录，不能指向代码仓库内部。
- RUN_ID：如 20260911_shan。省略时自动使用时间戳和 RUNNER/用户名；恢复时须使用原 ID，因此推荐总是显式填写。
- SAMPLES_MASTER：绝对路径；字段参见 [样本表说明](docs/SAMPLES_MASTER_GUIDE.md)。
- REFERENCE_FASTA/GTF：绝对路径；即使只跑部分模块，当前 launcher 仍要求提供这两个文件。
- NEXTFLOW_CONFIG：可选绝对路径的 Nextflow 配置，用于本地镜像/资源或站点设置。路径管理和保留 work 由 launcher 强制设置。
- RESUME=true：恢复同次运行。START_FROM 可选择模块起点，但此前所需输出必须存在。
- RESET_OUTPUTS=false：保留已有输出。true 会把对应输出目录重命名为带时间戳的备份，会增加空间占用。

OUTPUT_PROJECT_ROOT 已退休。旧 env 含 runs/default_project、runs_output 等路径会明确报错；请生成新 env，不要直接在旧缓存目录间搬动文件后声称能 resume。

## 运行状态与失败

每次启动产生新的记录目录，失败不会覆盖此前启动的日志。run.json 的 COMPLETED 表示该次启用的模块已通过；未启用模块没有被验证。查看 logs/nf-*.console.log 和 logs/nf-*/status.json。运行期间 .launcher.lock 阻止相同 RUN_ID 再次启动；不同 RUN_ID 各有独立 work 和缓存。机器异常中断留下锁时，确认 launcher 及计算作业都停止后才人工移除锁。

修复失败原因后用同一个 env 再提交。改变 FASTQ、样本定义、参考或分析阈值时用新 RUN_ID，避免模块自身的已有文件跳过逻辑复用旧结果。

## 分析边界

普通 Input FASTQ 和 ChIP 一起处理时，MACS3_SAMPLESHEET 留空，由 master 自动配对。复用外部 Input BAM 时提供显式 MACS3 样本表，并核对容器挂载；SHARED_CONTROL_MANIFEST 用于结果记录，不能代替 MACS3 配对。

保留默认 MACS3 q-value 0.1/0.05/0.01；下游部分 profile 名字仍固定。Consensus 自动模式要求每条件恰好两个 ChIP 重复；IDR 自动模式只选前两个。Pooled 样本不能当生物学重复。DiffBind 需要合适的条件/重复设计，当前 heatmap 依赖其输出。

更换物种时除了 FASTA/GTF，还要核对 MACS3/IDR genome size、bamCoverage effectiveGenomeSize 和 HOMER genome。chipfilter 当前做 MAPQ 过滤并统计线粒体比例，不等于实际删除线粒体或 BAM blacklist 区域。

## 结果交接与清理

1. 确认最新启动完成，启用模块的结果完整。
2. 保存各 *_output/ 和 02_run_record/ 到最终位置，并确认复制完整。
3. 删除本次 run 下整个 99_intermediate/。不需要进入里面逐个判断 BAM；删除后缓存恢复能力丢失。

不要改成把正式结果软链接到 work，否则清理会破坏结果。各 *_output/ 内的 trimmed FASTQ 和多个阶段 BAM 仍会占空间；它们不随中间目录删除。原始数据、软件安装、Java/Nextflow 框架和 Docker 镜像库单独管理。

[验证范围与测试](tests/README.md)。目录重构验证不能替代正式样品的生物学 QC。
