# 用户手册 — 标准 ChIP-seq 流程

## 适用范围与固定设置

当前标准版对应 Marjolein 这类小鼠双端样品：使用已处理的 liver Input 25L007941，每个样品独立跑 MACS3 q=0.05 和 q=0.01，不合并重复。[quick-start.md](quick-start.md) 提供完整命令和三张表的示例。其他物种、组织、CUT&RUN 或宽峰分析需要重新确认实验与参数适配性。

- 参考：GRCm39 / GENCODE vM27。
- FASTA：`/ictstr01/groups/idc/projects/uhlenhaut/jiang/reference/bwa/GRCm39_vM27/GRCm39.primary_assembly.genome.fa`。
- GTF：`/ictstr01/groups/idc/projects/uhlenhaut/jiang/reference/gtf/gencode.vM27.primary_assembly.annotation.gtf`。
- Input 根目录：`/ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/chip_runs/shared_input/liver/25L007941`。
- Input BAM：上述目录中的 `chipfilter_output/25L007941.nomulti.bam`。
- MAPQ：24；MACS3 两个阈值同时开启。

开启 FastQC、fastp、BWA、Picard、chipfilter、MACS3、bamCoverage、MultiQC 和交付汇总。关闭 IDR、peak consensus、DiffBind、FRiP、ChIPseeker、HOMER 和 heatmap。bigWig 是 ChIP coverage，不是减去 Input 后的轨道。

## 1. 创建本次运行

```bash
cd /ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/nextflow-chipseq
python3 scripts/new_run.py 20260914_marjolein
cd ../chip_runs/20260914_marjolein
```

每次使用新日期/运行人名称。新建脚本拒绝覆盖已有目录，生成 env、三张 CSV、挂载配置和提交脚本。不要创建额外 RUNNER 层级，也不要生成后随意搬动目录，因为配置与 submit.sh 保存了绝对路径。

## 2. 填写文件

| 文件 | 本次需要填写的内容 |
|---|---|
| pipeline.env | 邮箱、运行人；保留生成的 RUN_ID、路径和标准模块开关 |
| samples_master.csv | 新 ChIP 样品编号、真实条件、FASTQ R1/R2 绝对路径 |
| macs3_samplesheet.csv | 同样的样品编号；treatment_bam 留空，control_bam 保留固定 Input |
| shared_control_manifest.csv | 同样的样品编号；保留 control_id=25L007941 和 Input 根目录 |
| external_input.config | 保留共享 Input 根目录挂载，供容器读取 BAM 与 QC |
| submit.sh | 检查分区和 qos；保留生成的运行目录和启动命令 |

三张表都必须删除全部示例行，并填入相同的真实 sample_id。脚本不会在你修改 master 后自动同步另两张表，当前也没有保证三张表一致的交叉验证。

master 只填本次的新 ChIP FASTQ，不要加入已经处理的 shared Input。没有生物学重复时，各样品 replicate=1，condition 填真实实验条件，is_control=false、control_id 留空、use_for_idr=false、use_for_diffbind=false、enabled=true。名称与路径避免空格、逗号和 shell 特殊字符；第三个样品也必须正确区分 R1/R2。完整可复制表格见快速开始。

MACS3 表决定实际用哪个 BAM；manifest 供交付汇总读取 Input 身份与旧 QC，不代替 MACS3 表。env 中的 Input 注释仅用于说明，真正生效的是 CSV 路径与挂载配置。control_root 应包含 fastp_output、bwa_output、picard_output 和 chipfilter_output，不是 BAM 文件本身。

## 3. 提交和监控

确认批处理环境可用 Nextflow、Java、Python 3.8+ 和 Singularity。参考、Input 及容器必须可访问。

```bash
sbatch submit.sh
squeue -u "$USER"
```

下面 JOB_ID 替换为 sbatch 返回的数字：

```bash
tail -f launcher.JOB_ID.log
sacct -j JOB_ID --format=JobID,JobName,State,ExitCode,Elapsed
```

Ctrl+C 只退出日志查看。默认 submit.sh 调用 parallel-safe launcher，各模块提交自己的 Slurm 作业，因此队列中多个 job 是正常现象。模块详情在 `02_run_record/本次启动/logs/`，例如 nf-bwa.console.log。提交成功不等于运行成功；主日志应以 `[STATUS] COMPLETED` 结束，还要检查实际结果和 QC。

## 4. 结果与目录

```text
chip_runs/
  shared_input/liver/25L007941/  # 可复用 Input，不能随 run 清理
  20260914_marjolein/
    pipeline.env 与三张 CSV
    external_input.config、submit.sh
    launcher.JOB_ID.log
    *_output/
    02_run_record/              # 每次启动的配置、版本、日志、命令、状态
    99_intermediate/            # work、执行目录和缓存、临时文件、BWA 索引
```

- q=0.05 peaks：`macs3_output/consensus_q0.05/`。
- q=0.01 peaks：`macs3_output/strict_q0.01/`。
- bigWig：`bamcoverage_output/`。
- 综合 QC：`multiqc_output/`。
- 交付汇总：`result_delivery_output/`。

consensus_q0.05 只是 MACS3 分支目录名，不表示进行了重复间 consensus。lean 交付包主要是汇总，不包含所有需要保存的 peaks、轨道等模块结果。检查三个样品是否齐全、比对率、重复率、两档 peaks 与轨道；留意汇总表中的 NA。关闭的分析不在成功验证范围内。

## 5. 失败恢复与清理

失败后定位首个出错模块，修正原因；输入与代码不变时保留 RUN_ID、RESUME=true、RESET_OUTPUTS=false，重新 sbatch。保留 99_intermediate，不要同时启动同一个 run。机器异常留下锁时，必须确认 controller 和计算任务均已停止才能移除锁。

更换 FASTQ、参考、样品定义或 peak 阈值时用新 RUN_ID。某些模块会直接跳过已经存在的结果，单独关闭 resume 不能保证重新计算。平时 START_FROM 留空，不开启 RESET_OUTPUTS。

完成后检查并备份模块结果及 02_run_record，再删除本次 run 的 99_intermediate；删除后无法利用原缓存恢复。结果目录中已发布的 trimmed FASTQ 与各阶段 BAM 不会随之消失，仍占空间。不要删除原始数据、参考、共享 Input 或正在运行任务的数据。Nextflow 软件缓存和 Docker 镜像另行管理。

## 高级设置和验证范围

旧本地配置保存在 archive/configs/pipeline.advanced.env，完整可复用模板为 archive/configs/pipeline.advanced.env.example；默认启用全部模块，需要按实验设计检查。标准版 env 自包含，不再依赖隐藏默认开关。本地 Docker 运行还需要本地参考、Input 和容器配置，不能直接使用 HPC 路径。

当前标准配置和生成文件已进行本地检查；此前的合成数据测试不代表所有新版配置已在 HPC 跑完。真实验收以该 run 的日志和产物为准，测试范围见 [tests/README.md](tests/README.md)。docs 中旧教程仅作开发参考，日常操作以本手册和 quick-start.md 为准。
