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
RUN_ID="${RUN_ID:-$(date +%Y%m%d_%H%M%S)}"
RESET_OUTPUTS="${RESET_OUTPUTS:-false}"

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

prepare_module_output () {
  local module="$1"
  local outdir="$2"
  local p="${PIPELINES_ROOT}/${module}/${outdir}"
  if [[ "${RESET_OUTPUTS}" == "true" && -d "$p" ]]; then
    local bak="${p}.bak.${RUN_ID}"
    echo "[INFO] Archiving existing output: ${p} -> ${bak}"
    mv "$p" "$bak"
  fi
}

echo "[INFO] Using env file: ${ENV_FILE}"
echo "[INFO] Profile: ${PROFILE}"
echo "[INFO] Pipelines root: ${PIPELINES_ROOT}"

need_file "$REFERENCE_FASTA"
need_file "$GTF"
SAMPLES_MASTER="${SAMPLES_MASTER:-${PIPELINES_ROOT}/nextflow-chipseq/samples_master.csv}"
need_file "$SAMPLES_MASTER"
MASTER_ARGS=(--samples_master "$SAMPLES_MASTER")

# 1) FastQC
prepare_module_output nf-fastqc fastqc_output
run_nf nf-fastqc \
  "${MASTER_ARGS[@]}"

# 2) Fastp
prepare_module_output nf-fastp fastp_output
run_nf nf-fastp \
  "${MASTER_ARGS[@]}"

# 3) BWA
prepare_module_output nf-bwa bwa_output
run_nf nf-bwa \
  "${MASTER_ARGS[@]}" \
  --bwa_raw_data "${PIPELINES_ROOT}/nf-fastp/fastp_output" \
  --reference_fasta "$REFERENCE_FASTA"

# 4) Picard
prepare_module_output nf-picard picard_output
run_nf nf-picard \
  "${MASTER_ARGS[@]}" \
  --bwa_output "${PIPELINES_ROOT}/nf-bwa/bwa_output"

# 5) ChipFilter
prepare_module_output nf-chipfilter chipfilter_output
run_nf nf-chipfilter \
  "${MASTER_ARGS[@]}" \
  --chipfilter_raw_bam "${PIPELINES_ROOT}/nf-picard/picard_output"

# 6) MACS3 (auto from samples_master; optional explicit sheet override)
prepare_module_output nf-macs3 macs3_output
if [[ -n "${MACS3_SAMPLESHEET:-}" && -f "${MACS3_SAMPLESHEET}" ]]; then
  run_nf nf-macs3 \
    "${MASTER_ARGS[@]}" \
    --chipfilter_output "${PIPELINES_ROOT}/nf-chipfilter/chipfilter_output" \
    --macs3_samplesheet "$MACS3_SAMPLESHEET"
else
  run_nf nf-macs3 \
    "${MASTER_ARGS[@]}" \
    --chipfilter_output "${PIPELINES_ROOT}/nf-chipfilter/chipfilter_output"
fi

# 7) IDR (explicit pairs CSV or auto from samples_master)
prepare_module_output nf-idr idr_output
if [[ -n "${IDR_PAIRS_CSV:-}" && -f "${IDR_PAIRS_CSV}" ]]; then
  run_nf nf-idr \
    "${MASTER_ARGS[@]}" \
    --macs3_output "${PIPELINES_ROOT}/nf-macs3/macs3_output" \
    --idr_pairs_csv "$IDR_PAIRS_CSV"
else
  run_nf nf-idr \
    "${MASTER_ARGS[@]}" \
    --macs3_output "${PIPELINES_ROOT}/nf-macs3/macs3_output"
fi

# 8) ChIPseeker
prepare_module_output nf-chipseeker chipseeker_output
if [[ -n "${IDR_PAIRS_CSV:-}" && -f "${IDR_PAIRS_CSV}" ]]; then
  run_nf nf-chipseeker \
    --idr_output "${PIPELINES_ROOT}/nf-idr/idr_output" \
    --idr_pairs_csv "$IDR_PAIRS_CSV" \
    --gtf "$GTF"
else
  run_nf nf-chipseeker \
    --idr_output "${PIPELINES_ROOT}/nf-idr/idr_output" \
    --gtf "$GTF"
fi

# 9) FRiP (explicit sheet or auto from samples_master)
prepare_module_output nf-frip frip_output
if [[ -n "${FRIP_SAMPLESHEET:-}" && -f "${FRIP_SAMPLESHEET}" ]]; then
  run_nf nf-frip \
    "${MASTER_ARGS[@]}" \
    --frip_samplesheet "$FRIP_SAMPLESHEET"
else
  run_nf nf-frip \
    "${MASTER_ARGS[@]}" \
    --chipfilter_output "${PIPELINES_ROOT}/nf-chipfilter/chipfilter_output" \
    --idr_output "${PIPELINES_ROOT}/nf-idr/idr_output"
fi

# 10) bamCoverage
prepare_module_output nf-bamcoverage bamcoverage_output
run_nf nf-bamcoverage \
  "${MASTER_ARGS[@]}" \
  --bam_input_dir "${PIPELINES_ROOT}/nf-chipfilter/chipfilter_output" \
  --bam_pattern "${PIPELINES_ROOT}/nf-chipfilter/chipfilter_output/*.clean.bam"

# 11) deepTools heatmap (optional)
if [[ "${RUN_DEEPTOOLS_HEATMAP:-true}" == "true" ]]; then
  prepare_module_output nf-deeptools-heatmap deeptools_heatmap_output
  if [[ -n "${DEEPTOOLS_REGIONS_SHEET:-}" && -f "${DEEPTOOLS_REGIONS_SHEET}" ]]; then
    run_nf nf-deeptools-heatmap \
      "${MASTER_ARGS[@]}" \
      --bigwig_input_dir "${PIPELINES_ROOT}/nf-bamcoverage/bamcoverage_output/bigwig" \
      --regions_sheet "$DEEPTOOLS_REGIONS_SHEET"
else
    run_nf nf-deeptools-heatmap \
      "${MASTER_ARGS[@]}" \
      --bigwig_input_dir "${PIPELINES_ROOT}/nf-bamcoverage/bamcoverage_output/bigwig" \
      --idr_output "${PIPELINES_ROOT}/nf-idr/idr_output"
  fi
else
  echo "[INFO] Skip nf-deeptools-heatmap"
fi

# 12) DiffBind (optional)
if [[ "${RUN_DIFFBIND:-true}" == "true" ]]; then
  prepare_module_output nf-diffbind diffbind_output
  if [[ -n "${DIFFBIND_SAMPLESHEET:-}" && -f "${DIFFBIND_SAMPLESHEET}" ]]; then
    run_nf nf-diffbind \
      --samplesheet "$DIFFBIND_SAMPLESHEET"
else
    run_nf nf-diffbind \
      "${MASTER_ARGS[@]}" \
      --chipfilter_output "${PIPELINES_ROOT}/nf-chipfilter/chipfilter_output" \
      --macs3_output "${PIPELINES_ROOT}/nf-macs3/macs3_output"
  fi
else
  echo "[INFO] Skip nf-diffbind"
fi

# 13) HOMER motif + motif_compare (optional; default mode is motif_and_compare)
if [[ "${RUN_HOMER_MOTIF_COMPARE:-true}" == "true" ]]; then
  prepare_module_output nf-homer homer_output
  if [[ -n "${HOMER_MOTIF_COMPARE_SHEET:-}" && -f "${HOMER_MOTIF_COMPARE_SHEET}" ]]; then
    run_nf nf-homer \
      "${MASTER_ARGS[@]}" \
      --idr_pairs_csv "${IDR_PAIRS_CSV:-}" \
      --mode motif_and_compare \
      --motif_compare_sheet "$HOMER_MOTIF_COMPARE_SHEET"
else
    run_nf nf-homer \
      "${MASTER_ARGS[@]}" \
      --diffbind_output "${PIPELINES_ROOT}/nf-diffbind/diffbind_output"
  fi
else
  echo "[INFO] Skip nf-homer motif/motif_compare"
fi

# 14) Result delivery (optional)
if [[ "${RUN_RESULT_DELIVERY:-true}" == "true" ]]; then
  prepare_module_output nf-result-delivery result_delivery_output
  DELIVERY_ARGS=()
  [[ -n "${DELIVERY_TAG:-}" ]] && DELIVERY_ARGS+=(--delivery_tag "$DELIVERY_TAG")
  [[ -n "${DELIVERY_LEVEL:-}" ]] && DELIVERY_ARGS+=(--delivery_level "$DELIVERY_LEVEL")
  run_nf nf-result-delivery "${DELIVERY_ARGS[@]}"
else
  echo "[INFO] Skip nf-result-delivery"
fi

# 15) MultiQC summary (optional)
if [[ "${RUN_MULTIQC:-true}" == "true" ]]; then
  prepare_module_output nf-multiqc multiqc_output
  MULTIQC_ARGS=()
  [[ -n "${MULTIQC_TITLE:-}" ]] && MULTIQC_ARGS+=(--multiqc_title "$MULTIQC_TITLE")
  [[ -n "${MULTIQC_REPORT_NAME:-}" ]] && MULTIQC_ARGS+=(--multiqc_report_name "$MULTIQC_REPORT_NAME")
  [[ -n "${MULTIQC_EXTRA_PATHS:-}" ]] && MULTIQC_ARGS+=(--multiqc_extra_paths "$MULTIQC_EXTRA_PATHS")
  [[ -n "${MULTIQC_CONFIG:-}" ]] && MULTIQC_ARGS+=(--multiqc_config "$MULTIQC_CONFIG")

  run_nf nf-multiqc \
    --pipelines_root "${PIPELINES_ROOT}" \
    "${MULTIQC_ARGS[@]}"
else
  echo "[INFO] Skip nf-multiqc"
fi

echo
echo "[DONE] End-to-end pipeline finished."
