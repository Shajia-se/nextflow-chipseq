#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${1:-${ROOT_DIR}/pipeline.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: env file not found: $ENV_FILE"
  echo "Copy ${ROOT_DIR}/pipeline.env.example to ${ROOT_DIR}/pipeline.env and edit it."
  exit 1
fi

source "$ENV_FILE"

PROFILE="${PROFILE:-hpc}"
RESUME_FLAG=""
[[ "${RESUME:-true}" == "true" ]] && RESUME_FLAG="-resume"

PIPELINES_ROOT="${PIPELINES_ROOT:-/ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines}"

run_nf () {
  local module="$1"
  shift
  local module_dir="${PIPELINES_ROOT}/${module}"
  echo
  echo "========== ${module} =========="
  echo "cd ${module_dir}"
  cd "$module_dir"
  echo "nextflow run main.nf -profile ${PROFILE} $* ${RESUME_FLAG}"
  nextflow run main.nf -profile "${PROFILE}" "$@" ${RESUME_FLAG}
}

need_file () {
  local f="$1"
  [[ -f "$f" ]] || { echo "ERROR: missing file: $f"; exit 1; }
}

need_dir () {
  local d="$1"
  [[ -d "$d" ]] || { echo "ERROR: missing directory: $d"; exit 1; }
}

echo "[INFO] Using env file: ${ENV_FILE}"
echo "[INFO] Profile: ${PROFILE}"
echo "[INFO] Pipelines root: ${PIPELINES_ROOT}"

need_dir "$RAW_DATA_DIR"
need_file "$REFERENCE_FASTA"
need_file "$GTF"

# 1) FastQC
run_nf nf-fastqc \
  --fastqc_raw_data "$RAW_DATA_DIR" \
  --fastqc_pattern "$FASTQ_PATTERN_FASTQC"

# 2) Fastp
run_nf nf-fastp \
  --fastqc_raw_data "$RAW_DATA_DIR" \
  --fastp_pattern "$FASTQ_PATTERN_FASTP"

# 3) BWA
run_nf nf-bwa \
  --bwa_raw_data "${PIPELINES_ROOT}/nf-fastp/fastp_output" \
  --reference_fasta "$REFERENCE_FASTA"

# 4) Picard
run_nf nf-picard \
  --bwa_output "${PIPELINES_ROOT}/nf-bwa/bwa_output"

# 5) ChipFilter
run_nf nf-chipfilter \
  --chipfilter_raw_bam "${PIPELINES_ROOT}/nf-picard/picard_output"

# 6) MACS3 (requires sample sheet)
need_file "$MACS3_SAMPLESHEET"
run_nf nf-macs3 \
  --chipfilter_output "${PIPELINES_ROOT}/nf-chipfilter/chipfilter_output" \
  --macs3_samplesheet "$MACS3_SAMPLESHEET"

# 7) IDR (requires pairs csv)
need_file "$IDR_PAIRS_CSV"
run_nf nf-idr \
  --macs3_output "${PIPELINES_ROOT}/nf-macs3/macs3_output" \
  --idr_pairs_csv "$IDR_PAIRS_CSV"

# 8) ChIPseeker
run_nf nf-chipseeker \
  --idr_output "${PIPELINES_ROOT}/nf-idr/idr_output" \
  --gtf "$GTF"

# 9) FRiP (requires sample sheet)
need_file "$FRIP_SAMPLESHEET"
run_nf nf-frip \
  --frip_samplesheet "$FRIP_SAMPLESHEET"

# 10) bamCoverage
run_nf nf-bamcoverage \
  --bam_pattern "${PIPELINES_ROOT}/nf-chipfilter/chipfilter_output/*.clean.bam"

# 11) deepTools heatmap (optional)
if [[ "${RUN_DEEPTOOLS_HEATMAP:-true}" == "true" ]]; then
  need_file "$DEEPTOOLS_REGIONS_SHEET"
  run_nf nf-deeptools-heatmap \
    --regions_sheet "$DEEPTOOLS_REGIONS_SHEET"
else
  echo "[INFO] Skip nf-deeptools-heatmap"
fi

# 12) HOMER motif compare (optional)
if [[ "${RUN_HOMER_MOTIF_COMPARE:-true}" == "true" ]]; then
  need_file "$HOMER_MOTIF_COMPARE_SHEET"
  run_nf nf-homer \
    --mode motif_compare \
    --motif_compare_sheet "$HOMER_MOTIF_COMPARE_SHEET"
else
  echo "[INFO] Skip nf-homer motif_compare"
fi

# 13) DiffBind (optional)
if [[ "${RUN_DIFFBIND:-true}" == "true" ]]; then
  need_file "$DIFFBIND_SAMPLESHEET"
  run_nf nf-diffbind \
    --samplesheet "$DIFFBIND_SAMPLESHEET"
else
  echo "[INFO] Skip nf-diffbind"
fi

# 14) Result delivery (optional)
if [[ "${RUN_RESULT_DELIVERY:-true}" == "true" ]]; then
  if [[ -n "${DELIVERY_TAG:-}" ]]; then
    run_nf nf-result-delivery \
      --delivery_tag "$DELIVERY_TAG"
  else
    run_nf nf-result-delivery
  fi
else
  echo "[INFO] Skip nf-result-delivery"
fi

echo
echo "[DONE] End-to-end pipeline finished."
