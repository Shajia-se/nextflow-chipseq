#!/usr/bin/env bash
set -euo pipefail

OUTDIR="/ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/chip_runs/marjolein/X208SC26034859-Z01-F001/02.mergeRawData"

C1_R1="/ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/chip_runs/marjolein/X208SC26034859-Z01-F001/01.RawData/C1/C1_MKDL260004633-1A_23HH5YLT4_L7_1.fq.gz"
C1_R2="/ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/chip_runs/marjolein/X208SC26034859-Z01-F001/01.RawData/C1/C1_MKDL260004633-1A_23HH5YLT4_L7_2.fq.gz"
C2_R1="/ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/chip_runs/marjolein/X208SC26034859-Z01-F001/01.RawData/C2/C2_MKDL260004633-1A_23HH5YLT4_L7_1.fq.gz"
C2_R2="/ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/chip_runs/marjolein/X208SC26034859-Z01-F001/01.RawData/C2/C2_MKDL260004633-1A_23HH5YLT4_L7_2.fq.gz"
N2_R1="/ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/chip_runs/marjolein/X208SC26034859-Z01-F001/01.RawData/N2/N2_MKDL260004633-1A_23HH5YLT4_L7_1.fq.gz"
N2_R2="/ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/chip_runs/marjolein/X208SC26034859-Z01-F001/01.RawData/N2/N2_MKDL260004633-1A_23HH5YLT4_L7_2.fq.gz"
N3_R1="/ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/chip_runs/marjolein/X208SC26034859-Z01-F001/01.RawData/N3/N3_MKDL260004633-1A_23HH5YLT4_L7_1.fq.gz"
N3_R2="/ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/chip_runs/marjolein/X208SC26034859-Z01-F001/01.RawData/N3/N3_MKDL260004633-1A_23HH5YLT4_L7_2.fq.gz"

mkdir -p "$OUTDIR"

for f in \
  "$C1_R1" "$C1_R2" "$C2_R1" "$C2_R2" \
  "$N2_R1" "$N2_R2" "$N3_R1" "$N3_R2"
do
  [[ -s "$f" ]] || { echo "Missing input FASTQ: $f" >&2; exit 1; }
done

echo "[INFO] Writing pooled FASTQ files to $OUTDIR"

cat "$C1_R1" "$C2_R1" "$N2_R1" "$N3_R1" > "$OUTDIR/ALLpool_R1.fq.gz"
cat "$C1_R2" "$C2_R2" "$N2_R2" "$N3_R2" > "$OUTDIR/ALLpool_R2.fq.gz"

cat "$C1_R1" "$C2_R1" > "$OUTDIR/Cpool_R1.fq.gz"
cat "$C1_R2" "$C2_R2" > "$OUTDIR/Cpool_R2.fq.gz"

cat "$N2_R1" "$N3_R1" > "$OUTDIR/Npool_R1.fq.gz"
cat "$N2_R2" "$N3_R2" > "$OUTDIR/Npool_R2.fq.gz"

echo "[DONE] Created:"
echo "  $OUTDIR/ALLpool_R1.fq.gz"
echo "  $OUTDIR/ALLpool_R2.fq.gz"
echo "  $OUTDIR/Cpool_R1.fq.gz"
echo "  $OUTDIR/Cpool_R2.fq.gz"
echo "  $OUTDIR/Npool_R1.fq.gz"
echo "  $OUTDIR/Npool_R2.fq.gz"
