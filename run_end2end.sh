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
START_FROM="${START_FROM:-}"

PIPELINES_ROOT="${PIPELINES_ROOT:-/ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines}"
OUTPUT_PROJECT_ROOT="${OUTPUT_PROJECT_ROOT:-${PIPELINES_ROOT}/runs/default_project}"
RUN_FASTQC="${RUN_FASTQC:-true}"
RUN_FASTP="${RUN_FASTP:-true}"
RUN_BWA="${RUN_BWA:-true}"
RUN_PICARD="${RUN_PICARD:-true}"
RUN_CHIPFILTER="${RUN_CHIPFILTER:-true}"
RUN_MACS3="${RUN_MACS3:-true}"
RUN_IDR="${RUN_IDR:-true}"
RUN_PEAK_CONSENSUS="${RUN_PEAK_CONSENSUS:-true}"
RUN_DIFFBIND="${RUN_DIFFBIND:-true}"
RUN_BAMCOVERAGE="${RUN_BAMCOVERAGE:-true}"
RUN_FRIP="${RUN_FRIP:-true}"
RUN_CHIPSEEKER="${RUN_CHIPSEEKER:-true}"
RUN_HOMER="${RUN_HOMER:-${RUN_HOMER_MOTIF_COMPARE:-true}}"
RUN_DEEPTOOLS_HEATMAP="${RUN_DEEPTOOLS_HEATMAP:-true}"
RUN_RESULT_DELIVERY="${RUN_RESULT_DELIVERY:-true}"
RUN_MULTIQC="${RUN_MULTIQC:-true}"

ACTIVE_RUN_ROOT="${OUTPUT_PROJECT_ROOT%/}/${RUN_ID}"
mkdir -p "${ACTIVE_RUN_ROOT}"

FASTQC_OUT="${ACTIVE_RUN_ROOT}/fastqc_output"
FASTP_OUT="${ACTIVE_RUN_ROOT}/fastp_output"
BWA_OUT="${ACTIVE_RUN_ROOT}/bwa_output"
PICARD_OUT="${ACTIVE_RUN_ROOT}/picard_output"
CHIPFILTER_OUT="${ACTIVE_RUN_ROOT}/chipfilter_output"
MACS3_OUT="${ACTIVE_RUN_ROOT}/macs3_output"
IDR_OUT="${ACTIVE_RUN_ROOT}/idr_output"
PEAK_CONSENSUS_OUT="${ACTIVE_RUN_ROOT}/peak_consensus_output"
DIFFBIND_OUT="${ACTIVE_RUN_ROOT}/diffbind_output"
BAMCOVERAGE_OUT="${ACTIVE_RUN_ROOT}/bamcoverage_output"
FRIP_OUT="${ACTIVE_RUN_ROOT}/frip_output"
CHIPSEEKER_OUT="${ACTIVE_RUN_ROOT}/chipseeker_output"
HOMER_OUT="${ACTIVE_RUN_ROOT}/homer_output"
DEEPTOOLS_OUT="${ACTIVE_RUN_ROOT}/deeptools_heatmap_output"
RESULT_DELIVERY_OUT="${ACTIVE_RUN_ROOT}/result_delivery_output"
MULTIQC_OUT="${ACTIVE_RUN_ROOT}/multiqc_output"

join_by_comma () {
  local IFS=','
  echo "$*"
}

module_index () {
  case "$1" in
    fastqc) echo 10 ;;
    fastp) echo 20 ;;
    bwa) echo 30 ;;
    picard) echo 40 ;;
    chipfilter) echo 50 ;;
    macs3) echo 60 ;;
    idr) echo 70 ;;
    peak_consensus) echo 80 ;;
    diffbind) echo 90 ;;
    bamcoverage) echo 100 ;;
    frip) echo 110 ;;
    chipseeker) echo 120 ;;
    homer) echo 130 ;;
    deeptools) echo 140 ;;
    result_delivery) echo 150 ;;
    multiqc) echo 160 ;;
    *) echo -1 ;;
  esac
}

should_run () {
  local module="$1"
  local flag="$2"
  [[ "$flag" == "true" ]] || return 1
  [[ -z "${START_FROM}" ]] && return 0

  local m_idx s_idx
  m_idx="$(module_index "$module")"
  s_idx="$(module_index "${START_FROM}")"
  [[ "$m_idx" -ge 0 && "$s_idx" -ge 0 ]] || return 1
  [[ "$m_idx" -ge "$s_idx" ]]
}

run_nf () {
  local module="$1"
  shift
  local module_dir="${PIPELINES_ROOT}/${module}"
  echo
  echo "========== ${module} =========="
  echo "cd ${module_dir}"
  cd "$module_dir"
  echo "nextflow run main.nf -profile ${PROFILE} --project_folder ${ACTIVE_RUN_ROOT} $* ${RESUME_FLAG}"
  nextflow run main.nf -profile "${PROFILE}" --project_folder "${ACTIVE_RUN_ROOT}" "$@" ${RESUME_FLAG}
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
  local p="${ACTIVE_RUN_ROOT}/${outdir}"

  if [[ "$outdir" == "result_delivery_output" ]]; then
    echo "[INFO] Keep delivery root as-is: ${p}"
    return 0
  fi

  if [[ "${RESET_OUTPUTS}" == "true" && -d "$p" ]]; then
    local ts
    ts="$(date +%Y%m%d_%H%M%S)"
    local bak="${p}.bak.${ts}"
    echo "[INFO] Archiving existing output: ${p} -> ${bak}"
    mv "$p" "$bak"
  fi
}

echo "[INFO] Using env file: ${ENV_FILE}"
echo "[INFO] Profile: ${PROFILE}"
echo "[INFO] Pipelines root: ${PIPELINES_ROOT}"
echo "[INFO] Output project root: ${OUTPUT_PROJECT_ROOT}"
echo "[INFO] Active run root: ${ACTIVE_RUN_ROOT}"
[[ -n "${START_FROM}" ]] && echo "[INFO] START_FROM: ${START_FROM}"

if [[ -n "${START_FROM}" ]] && [[ "$(module_index "${START_FROM}")" -lt 0 ]]; then
  echo "ERROR: invalid START_FROM='${START_FROM}'"
  echo "Valid values: fastqc,fastp,bwa,picard,chipfilter,macs3,idr,peak_consensus,diffbind,bamcoverage,frip,chipseeker,homer,deeptools,result_delivery,multiqc"
  exit 1
fi

need_file "$REFERENCE_FASTA"
need_file "$GTF"
SAMPLES_MASTER="${SAMPLES_MASTER:-${PIPELINES_ROOT}/nextflow-chipseq/samples_master.csv}"
need_file "$SAMPLES_MASTER"
MASTER_ARGS=(--samples_master "$SAMPLES_MASTER")

FRIP_SOURCES_DEFAULT=()
[[ "${RUN_IDR}" == "true" ]] && FRIP_SOURCES_DEFAULT+=("idr")
if [[ "${RUN_PEAK_CONSENSUS}" == "true" ]]; then
  FRIP_SOURCES_DEFAULT+=("consensus_q0.01" "consensus_q0.05")
fi
FRIP_PEAK_SOURCES="${FRIP_PEAK_SOURCES:-$(join_by_comma "${FRIP_SOURCES_DEFAULT[@]}")}"

CHIPSEEKER_SOURCES_DEFAULT=()
[[ "${RUN_IDR}" == "true" ]] && CHIPSEEKER_SOURCES_DEFAULT+=("idr")
if [[ "${RUN_PEAK_CONSENSUS}" == "true" ]]; then
  CHIPSEEKER_SOURCES_DEFAULT+=("consensus_q0.01" "consensus_q0.05")
fi
[[ "${RUN_DIFFBIND}" == "true" ]] && CHIPSEEKER_SOURCES_DEFAULT+=("diffbind")
CHIPSEEKER_PEAK_SOURCES="${CHIPSEEKER_PEAK_SOURCES:-$(join_by_comma "${CHIPSEEKER_SOURCES_DEFAULT[@]}")}"

HOMER_SOURCES_DEFAULT=()
[[ "${RUN_IDR}" == "true" ]] && HOMER_SOURCES_DEFAULT+=("idr")
if [[ "${RUN_PEAK_CONSENSUS}" == "true" ]]; then
  HOMER_SOURCES_DEFAULT+=("consensus_q0.01" "consensus_q0.05")
fi
HOMER_PEAK_SOURCES="${HOMER_PEAK_SOURCES:-$(join_by_comma "${HOMER_SOURCES_DEFAULT[@]}")}"

# 1) FastQC
if should_run fastqc "${RUN_FASTQC}"; then
  prepare_module_output nf-fastqc fastqc_output
  run_nf nf-fastqc \
    "${MASTER_ARGS[@]}"
else
  echo "[INFO] Skip nf-fastqc"
fi

# 2) Fastp
if should_run fastp "${RUN_FASTP}"; then
  prepare_module_output nf-fastp fastp_output
  run_nf nf-fastp \
    "${MASTER_ARGS[@]}"
else
  echo "[INFO] Skip nf-fastp"
fi

# 3) BWA
if should_run bwa "${RUN_BWA}"; then
  prepare_module_output nf-bwa bwa_output
  run_nf nf-bwa \
    "${MASTER_ARGS[@]}" \
    --bwa_raw_data "${FASTP_OUT}" \
    --reference_fasta "$REFERENCE_FASTA"
else
  echo "[INFO] Skip nf-bwa"
fi

# 4) Picard
if should_run picard "${RUN_PICARD}"; then
  prepare_module_output nf-picard picard_output
  run_nf nf-picard \
    "${MASTER_ARGS[@]}" \
    --bwa_output "${BWA_OUT}"
else
  echo "[INFO] Skip nf-picard"
fi

# 5) ChipFilter
if should_run chipfilter "${RUN_CHIPFILTER}"; then
  prepare_module_output nf-chipfilter chipfilter_output
  run_nf nf-chipfilter \
    "${MASTER_ARGS[@]}" \
    --chipfilter_raw_bam "${PICARD_OUT}"
else
  echo "[INFO] Skip nf-chipfilter"
fi

# 6) MACS3
#    default output branches:
#    - idr_q0.1
#    - strict_q0.01
if should_run macs3 "${RUN_MACS3}"; then
  prepare_module_output nf-macs3 macs3_output
  if [[ -n "${MACS3_SAMPLESHEET:-}" && -f "${MACS3_SAMPLESHEET}" ]]; then
    run_nf nf-macs3 \
      "${MASTER_ARGS[@]}" \
      --chipfilter_output "${CHIPFILTER_OUT}" \
      --macs3_samplesheet "$MACS3_SAMPLESHEET"
  else
    run_nf nf-macs3 \
      "${MASTER_ARGS[@]}" \
      --chipfilter_output "${CHIPFILTER_OUT}"
  fi
else
  echo "[INFO] Skip nf-macs3"
fi

# 7) IDR (optional; default MACS3 profile: idr_q0.1)
if should_run idr "${RUN_IDR}"; then
  prepare_module_output nf-idr idr_output
  if [[ -n "${IDR_PAIRS_CSV:-}" && -f "${IDR_PAIRS_CSV}" ]]; then
    run_nf nf-idr \
      "${MASTER_ARGS[@]}" \
      --macs3_output "${MACS3_OUT}" \
      --idr_pairs_csv "$IDR_PAIRS_CSV"
  else
    run_nf nf-idr \
      "${MASTER_ARGS[@]}" \
      --macs3_output "${MACS3_OUT}"
  fi
else
  echo "[INFO] Skip nf-idr"
fi

# 8) Peak consensus (optional; default MACS3 profile: strict_q0.01)
if should_run peak_consensus "${RUN_PEAK_CONSENSUS}"; then
  prepare_module_output nf-peak-consensus peak_consensus_output
  if [[ -n "${CONSENSUS_PAIRS_CSV:-}" && -f "${CONSENSUS_PAIRS_CSV}" ]]; then
    run_nf nf-peak-consensus \
      --consensus_pairs_csv "$CONSENSUS_PAIRS_CSV"
  else
    run_nf nf-peak-consensus \
      "${MASTER_ARGS[@]}" \
      --macs3_output "${MACS3_OUT}"
  fi
else
  echo "[INFO] Skip nf-peak-consensus"
fi

# 9) FRiP (explicit sheet or auto from samples_master; default peak sets: idr + consensus)
if should_run frip "${RUN_FRIP}" && [[ -n "${FRIP_PEAK_SOURCES}" ]]; then
  prepare_module_output nf-frip frip_output
  if [[ -n "${FRIP_SAMPLESHEET:-}" && -f "${FRIP_SAMPLESHEET}" ]]; then
    run_nf nf-frip \
      "${MASTER_ARGS[@]}" \
      --frip_samplesheet "$FRIP_SAMPLESHEET"
  else
    run_nf nf-frip \
      "${MASTER_ARGS[@]}" \
      --chipfilter_output "${CHIPFILTER_OUT}" \
      --idr_output "${IDR_OUT}" \
      --peak_consensus_output "${PEAK_CONSENSUS_OUT}" \
      --frip_peak_sources "${FRIP_PEAK_SOURCES}"
  fi
else
  echo "[INFO] Skip nf-frip (no enabled peak sources)"
fi

# 10) bamCoverage
if should_run bamcoverage "${RUN_BAMCOVERAGE}"; then
  prepare_module_output nf-bamcoverage bamcoverage_output
  run_nf nf-bamcoverage \
    "${MASTER_ARGS[@]}" \
    --bam_input_dir "${CHIPFILTER_OUT}" \
    --bam_pattern "${CHIPFILTER_OUT}/*.clean.bam"
else
  echo "[INFO] Skip nf-bamcoverage"
fi

# 11) DiffBind (optional; default MACS3 profile: strict_q0.01)
if should_run diffbind "${RUN_DIFFBIND}"; then
  prepare_module_output nf-diffbind diffbind_output
  if [[ -n "${DIFFBIND_SAMPLESHEET:-}" && -f "${DIFFBIND_SAMPLESHEET}" ]]; then
    run_nf nf-diffbind \
      --samplesheet "$DIFFBIND_SAMPLESHEET"
else
    run_nf nf-diffbind \
      "${MASTER_ARGS[@]}" \
      --chipfilter_output "${CHIPFILTER_OUT}" \
      --macs3_output "${MACS3_OUT}"
  fi
else
  echo "[INFO] Skip nf-diffbind"
fi

# 12) ChIPseeker (default peak sets: idr + consensus + diffbind)
if should_run chipseeker "${RUN_CHIPSEEKER}" && [[ -n "${CHIPSEEKER_PEAK_SOURCES}" ]]; then
  prepare_module_output nf-chipseeker chipseeker_output
  if [[ -n "${IDR_PAIRS_CSV:-}" && -f "${IDR_PAIRS_CSV}" ]]; then
    run_nf nf-chipseeker \
      --idr_output "${IDR_OUT}" \
      --peak_consensus_output "${PEAK_CONSENSUS_OUT}" \
      --diffbind_output "${DIFFBIND_OUT}" \
      --chipseeker_peak_sources "${CHIPSEEKER_PEAK_SOURCES}" \
      --idr_pairs_csv "$IDR_PAIRS_CSV" \
      --gtf "$GTF"
  else
    run_nf nf-chipseeker \
      --idr_output "${IDR_OUT}" \
      --peak_consensus_output "${PEAK_CONSENSUS_OUT}" \
      --diffbind_output "${DIFFBIND_OUT}" \
      --chipseeker_peak_sources "${CHIPSEEKER_PEAK_SOURCES}" \
      --gtf "$GTF"
  fi
else
  echo "[INFO] Skip nf-chipseeker (no enabled peak sources)"
fi

# 13) HOMER motif + motif_compare (optional; default motif sources: idr + consensus + diffbind)
if should_run homer "${RUN_HOMER}"; then
  if [[ -n "${HOMER_PEAK_SOURCES}" ]]; then
    prepare_module_output nf-homer homer_output
    if [[ -n "${HOMER_MOTIF_COMPARE_SHEET:-}" && -f "${HOMER_MOTIF_COMPARE_SHEET}" ]]; then
      run_nf nf-homer \
        "${MASTER_ARGS[@]}" \
        --idr_output "${IDR_OUT}" \
        --peak_consensus_output "${PEAK_CONSENSUS_OUT}" \
        --diffbind_output "${DIFFBIND_OUT}" \
        --homer_peak_sources "${HOMER_PEAK_SOURCES}" \
        --idr_pairs_csv "${IDR_PAIRS_CSV:-}" \
        --mode motif_and_compare \
        --motif_compare_sheet "$HOMER_MOTIF_COMPARE_SHEET"
    else
      run_nf nf-homer \
        "${MASTER_ARGS[@]}" \
        --idr_output "${IDR_OUT}" \
        --peak_consensus_output "${PEAK_CONSENSUS_OUT}" \
        --diffbind_output "${DIFFBIND_OUT}" \
        --homer_peak_sources "${HOMER_PEAK_SOURCES}"
    fi
  else
    echo "[INFO] Skip nf-homer motif/motif_compare (no enabled peak sources)"
  fi
else
  echo "[INFO] Skip nf-homer motif/motif_compare"
fi

# 14) deepTools heatmap (optional; scaled BAM -> mean tracks -> DiffBind gain/loss heatmap)
if should_run deeptools "${RUN_DEEPTOOLS_HEATMAP}"; then
  prepare_module_output nf-deeptools-heatmap deeptools_heatmap_output
  run_nf nf-deeptools-heatmap \
    "${MASTER_ARGS[@]}" \
    --chipfilter_output "${CHIPFILTER_OUT}" \
    --macs3_output "${MACS3_OUT}" \
    --diffbind_output "${DIFFBIND_OUT}"
else
  echo "[INFO] Skip nf-deeptools-heatmap"
fi

# 15) Result delivery (optional)
if should_run result_delivery "${RUN_RESULT_DELIVERY}"; then
  prepare_module_output nf-result-delivery result_delivery_output
  DELIVERY_ARGS=()
  [[ -n "${DELIVERY_TAG:-}" ]] && DELIVERY_ARGS+=(--delivery_tag "$DELIVERY_TAG")
  [[ -n "${DELIVERY_LEVEL:-}" ]] && DELIVERY_ARGS+=(--delivery_level "$DELIVERY_LEVEL")
  run_nf nf-result-delivery \
    --samples_master "$SAMPLES_MASTER" \
    --fastp_out "${FASTP_OUT}" \
    --bwa_out "${BWA_OUT}" \
    --picard_out "${PICARD_OUT}" \
    --chipfilter_out "${CHIPFILTER_OUT}" \
    --frip_out "${FRIP_OUT}" \
    --idr_out "${IDR_OUT}" \
    --peak_consensus_out "${PEAK_CONSENSUS_OUT}" \
    --macs3_out "${MACS3_OUT}" \
    --diffbind_out "${DIFFBIND_OUT}" \
    --deeptools_out "${DEEPTOOLS_OUT}" \
    --homer_out "${HOMER_OUT}" \
    --chipseeker_out "${CHIPSEEKER_OUT}" \
    --bw_out "${BAMCOVERAGE_OUT}/bigwig" \
    --multiqc_out "${MULTIQC_OUT}" \
    "${DELIVERY_ARGS[@]}"
else
  echo "[INFO] Skip nf-result-delivery"
fi

# 16) MultiQC summary (optional)
if should_run multiqc "${RUN_MULTIQC}"; then
  prepare_module_output nf-multiqc multiqc_output
  MULTIQC_ARGS=()
  [[ -n "${MULTIQC_TITLE:-}" ]] && MULTIQC_ARGS+=(--multiqc_title "$MULTIQC_TITLE")
  [[ -n "${MULTIQC_REPORT_NAME:-}" ]] && MULTIQC_ARGS+=(--multiqc_report_name "$MULTIQC_REPORT_NAME")
  [[ -n "${MULTIQC_EXTRA_PATHS:-}" ]] && MULTIQC_ARGS+=(--multiqc_extra_paths "$MULTIQC_EXTRA_PATHS")
  [[ -n "${MULTIQC_CONFIG:-}" ]] && MULTIQC_ARGS+=(--multiqc_config "$MULTIQC_CONFIG")

  run_nf nf-multiqc \
    --flat_output_root "${ACTIVE_RUN_ROOT}" \
    "${MULTIQC_ARGS[@]}"
else
  echo "[INFO] Skip nf-multiqc"
fi

echo
echo "[DONE] End-to-end pipeline finished."
