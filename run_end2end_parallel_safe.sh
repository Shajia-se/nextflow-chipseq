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
START_FROM="${START_FROM:-}"

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

LOG_DIR="${ROOT_DIR}/logs"
mkdir -p "$LOG_DIR"

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

need_file () {
  local f="$1"
  [[ -f "$f" ]] || { echo "ERROR: missing file: $f"; exit 1; }
}

prepare_module_output () {
  local module="$1"
  local outdir="$2"
  local p="${PIPELINES_ROOT}/${module}/${outdir}"

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

run_nf () {
  local module="$1"
  shift
  local module_dir="${PIPELINES_ROOT}/${module}"
  local log_file="${LOG_DIR}/${RUN_ID}_${module}.log"

  echo
  echo "========== ${module} (sequential) =========="
  echo "cd ${module_dir}"
  echo "nextflow run main.nf -profile ${PROFILE} $* ${RESUME_FLAG}"

  (
    set -euo pipefail
    cd "$module_dir"
    nextflow run main.nf -profile "$PROFILE" "$@" ${RESUME_FLAG}
  ) 2>&1 | tee "$log_file"
}

PIDS=()
NAMES=()

launch_nf_bg () {
  local module="$1"
  shift
  local module_dir="${PIPELINES_ROOT}/${module}"
  local log_file="${LOG_DIR}/${RUN_ID}_${module}.log"

  echo
  echo "========== ${module} (parallel launch) =========="
  echo "cd ${module_dir}"
  echo "nextflow run main.nf -profile ${PROFILE} $* ${RESUME_FLAG}"

  (
    set -euo pipefail
    cd "$module_dir"
    nextflow run main.nf -profile "$PROFILE" "$@" ${RESUME_FLAG}
  ) >"$log_file" 2>&1 &

  local pid=$!
  PIDS+=("$pid")
  NAMES+=("$module")
  echo "[INFO] Launched ${module} (pid=${pid}), log=${log_file}"
}

wait_wave () {
  local wave_name="$1"
  local failed=0

  echo
  echo "========== WAIT ${wave_name} =========="
  for i in "${!PIDS[@]}"; do
    local pid="${PIDS[$i]}"
    local name="${NAMES[$i]}"

    if wait "$pid"; then
      echo "[OK] ${name} finished"
    else
      echo "[ERROR] ${name} failed (see ${LOG_DIR}/${RUN_ID}_${name}.log)"
      failed=1
    fi
  done

  PIDS=()
  NAMES=()

  if [[ "$failed" -ne 0 ]]; then
    echo "[FATAL] ${wave_name} failed. Stop pipeline."
    exit 1
  fi
}


echo "[INFO] Using env file: ${ENV_FILE}"
echo "[INFO] Profile: ${PROFILE}"
echo "[INFO] Pipelines root: ${PIPELINES_ROOT}"
echo "[INFO] Run ID: ${RUN_ID}"
echo "[INFO] Logs: ${LOG_DIR}"
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
[[ "${RUN_PEAK_CONSENSUS}" == "true" ]] && FRIP_SOURCES_DEFAULT+=("consensus")
FRIP_PEAK_SOURCES="${FRIP_PEAK_SOURCES:-$(join_by_comma "${FRIP_SOURCES_DEFAULT[@]}")}"

CHIPSEEKER_SOURCES_DEFAULT=()
[[ "${RUN_IDR}" == "true" ]] && CHIPSEEKER_SOURCES_DEFAULT+=("idr")
[[ "${RUN_PEAK_CONSENSUS}" == "true" ]] && CHIPSEEKER_SOURCES_DEFAULT+=("consensus")
[[ "${RUN_DIFFBIND}" == "true" ]] && CHIPSEEKER_SOURCES_DEFAULT+=("diffbind")
CHIPSEEKER_PEAK_SOURCES="${CHIPSEEKER_PEAK_SOURCES:-$(join_by_comma "${CHIPSEEKER_SOURCES_DEFAULT[@]}")}"

HOMER_SOURCES_DEFAULT=()
[[ "${RUN_IDR}" == "true" ]] && HOMER_SOURCES_DEFAULT+=("idr")
[[ "${RUN_PEAK_CONSENSUS}" == "true" ]] && HOMER_SOURCES_DEFAULT+=("consensus")
HOMER_PEAK_SOURCES="${HOMER_PEAK_SOURCES:-$(join_by_comma "${HOMER_SOURCES_DEFAULT[@]}")}"

# ------------------------
# Wave 0: strict sequence
# ------------------------
if should_run fastqc "${RUN_FASTQC}"; then
  prepare_module_output nf-fastqc fastqc_output
  run_nf nf-fastqc "${MASTER_ARGS[@]}"
else
  echo "[INFO] Skip nf-fastqc"
fi

if should_run fastp "${RUN_FASTP}"; then
  prepare_module_output nf-fastp fastp_output
  run_nf nf-fastp "${MASTER_ARGS[@]}"
else
  echo "[INFO] Skip nf-fastp"
fi

if should_run bwa "${RUN_BWA}"; then
  prepare_module_output nf-bwa bwa_output
  run_nf nf-bwa \
    "${MASTER_ARGS[@]}" \
    --bwa_raw_data "${PIPELINES_ROOT}/nf-fastp/fastp_output" \
    --reference_fasta "$REFERENCE_FASTA"
else
  echo "[INFO] Skip nf-bwa"
fi

if should_run picard "${RUN_PICARD}"; then
  prepare_module_output nf-picard picard_output
  run_nf nf-picard \
    "${MASTER_ARGS[@]}" \
    --bwa_output "${PIPELINES_ROOT}/nf-bwa/bwa_output"
else
  echo "[INFO] Skip nf-picard"
fi

if should_run chipfilter "${RUN_CHIPFILTER}"; then
  prepare_module_output nf-chipfilter chipfilter_output
  run_nf nf-chipfilter \
    "${MASTER_ARGS[@]}" \
    --chipfilter_raw_bam "${PIPELINES_ROOT}/nf-picard/picard_output"
else
  echo "[INFO] Skip nf-chipfilter"
fi

if should_run macs3 "${RUN_MACS3}"; then
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
else
  echo "[INFO] Skip nf-macs3"
fi

# ------------------------------------------
# Wave 1: parallel after MACS3/chipfilter
# ------------------------------------------
if should_run idr "${RUN_IDR}"; then
  prepare_module_output nf-idr idr_output
  if [[ -n "${IDR_PAIRS_CSV:-}" && -f "${IDR_PAIRS_CSV}" ]]; then
    launch_nf_bg nf-idr \
      "${MASTER_ARGS[@]}" \
      --macs3_output "${PIPELINES_ROOT}/nf-macs3/macs3_output" \
      --idr_pairs_csv "$IDR_PAIRS_CSV"
  else
    launch_nf_bg nf-idr \
      "${MASTER_ARGS[@]}" \
      --macs3_output "${PIPELINES_ROOT}/nf-macs3/macs3_output"
  fi
else
  echo "[INFO] Skip nf-idr"
fi

if should_run peak_consensus "${RUN_PEAK_CONSENSUS}"; then
  prepare_module_output nf-peak-consensus peak_consensus_output
  if [[ -n "${CONSENSUS_PAIRS_CSV:-}" && -f "${CONSENSUS_PAIRS_CSV}" ]]; then
    launch_nf_bg nf-peak-consensus --consensus_pairs_csv "$CONSENSUS_PAIRS_CSV"
  else
    launch_nf_bg nf-peak-consensus "${MASTER_ARGS[@]}"
  fi
else
  echo "[INFO] Skip nf-peak-consensus"
fi

if should_run diffbind "${RUN_DIFFBIND}"; then
  prepare_module_output nf-diffbind diffbind_output
  if [[ -n "${DIFFBIND_SAMPLESHEET:-}" && -f "${DIFFBIND_SAMPLESHEET}" ]]; then
    launch_nf_bg nf-diffbind --samplesheet "$DIFFBIND_SAMPLESHEET"
  else
    launch_nf_bg nf-diffbind \
      "${MASTER_ARGS[@]}" \
      --chipfilter_output "${PIPELINES_ROOT}/nf-chipfilter/chipfilter_output" \
      --macs3_output "${PIPELINES_ROOT}/nf-macs3/macs3_output"
  fi
else
  echo "[INFO] Skip nf-diffbind"
fi

if should_run bamcoverage "${RUN_BAMCOVERAGE}"; then
  prepare_module_output nf-bamcoverage bamcoverage_output
  launch_nf_bg nf-bamcoverage \
    "${MASTER_ARGS[@]}" \
    --bam_input_dir "${PIPELINES_ROOT}/nf-chipfilter/chipfilter_output" \
    --bam_pattern "${PIPELINES_ROOT}/nf-chipfilter/chipfilter_output/*.clean.bam"
else
  echo "[INFO] Skip nf-bamcoverage"
fi

wait_wave "WAVE1"

# ------------------------------------------
# Wave 2: parallel downstream analytics
# ------------------------------------------
if should_run frip "${RUN_FRIP}" && [[ -n "${FRIP_PEAK_SOURCES}" ]]; then
  prepare_module_output nf-frip frip_output
  if [[ -n "${FRIP_SAMPLESHEET:-}" && -f "${FRIP_SAMPLESHEET}" ]]; then
    launch_nf_bg nf-frip \
      "${MASTER_ARGS[@]}" \
      --frip_samplesheet "$FRIP_SAMPLESHEET"
  else
    launch_nf_bg nf-frip \
      "${MASTER_ARGS[@]}" \
      --chipfilter_output "${PIPELINES_ROOT}/nf-chipfilter/chipfilter_output" \
      --idr_output "${PIPELINES_ROOT}/nf-idr/idr_output" \
      --peak_consensus_output "${PIPELINES_ROOT}/nf-peak-consensus/peak_consensus_output" \
      --frip_peak_sources "${FRIP_PEAK_SOURCES}"
  fi
else
  echo "[INFO] Skip nf-frip (no enabled peak sources)"
fi

if should_run chipseeker "${RUN_CHIPSEEKER}" && [[ -n "${CHIPSEEKER_PEAK_SOURCES}" ]]; then
  prepare_module_output nf-chipseeker chipseeker_output
  if [[ -n "${IDR_PAIRS_CSV:-}" && -f "${IDR_PAIRS_CSV}" ]]; then
    launch_nf_bg nf-chipseeker \
      --idr_output "${PIPELINES_ROOT}/nf-idr/idr_output" \
      --peak_consensus_output "${PIPELINES_ROOT}/nf-peak-consensus/peak_consensus_output" \
      --diffbind_output "${PIPELINES_ROOT}/nf-diffbind/diffbind_output" \
      --chipseeker_peak_sources "${CHIPSEEKER_PEAK_SOURCES}" \
      --idr_pairs_csv "$IDR_PAIRS_CSV" \
      --gtf "$GTF"
  else
    launch_nf_bg nf-chipseeker \
      --idr_output "${PIPELINES_ROOT}/nf-idr/idr_output" \
      --peak_consensus_output "${PIPELINES_ROOT}/nf-peak-consensus/peak_consensus_output" \
      --diffbind_output "${PIPELINES_ROOT}/nf-diffbind/diffbind_output" \
      --chipseeker_peak_sources "${CHIPSEEKER_PEAK_SOURCES}" \
      --gtf "$GTF"
  fi
else
  echo "[INFO] Skip nf-chipseeker (no enabled peak sources)"
fi

if should_run homer "${RUN_HOMER}"; then
  if [[ -n "${HOMER_PEAK_SOURCES}" ]]; then
    prepare_module_output nf-homer homer_output
    if [[ -n "${HOMER_MOTIF_COMPARE_SHEET:-}" && -f "${HOMER_MOTIF_COMPARE_SHEET}" ]]; then
      launch_nf_bg nf-homer \
        "${MASTER_ARGS[@]}" \
        --idr_output "${PIPELINES_ROOT}/nf-idr/idr_output" \
        --peak_consensus_output "${PIPELINES_ROOT}/nf-peak-consensus/peak_consensus_output" \
        --diffbind_output "${PIPELINES_ROOT}/nf-diffbind/diffbind_output" \
        --homer_peak_sources "${HOMER_PEAK_SOURCES}" \
        --idr_pairs_csv "${IDR_PAIRS_CSV:-}" \
        --mode motif_and_compare \
        --motif_compare_sheet "$HOMER_MOTIF_COMPARE_SHEET"
    else
      launch_nf_bg nf-homer \
        "${MASTER_ARGS[@]}" \
        --idr_output "${PIPELINES_ROOT}/nf-idr/idr_output" \
        --peak_consensus_output "${PIPELINES_ROOT}/nf-peak-consensus/peak_consensus_output" \
        --diffbind_output "${PIPELINES_ROOT}/nf-diffbind/diffbind_output" \
        --homer_peak_sources "${HOMER_PEAK_SOURCES}"
    fi
  else
    echo "[INFO] Skip nf-homer motif/motif_compare (no enabled peak sources)"
  fi
else
  echo "[INFO] Skip nf-homer motif/motif_compare"
fi

if should_run deeptools "${RUN_DEEPTOOLS_HEATMAP}"; then
  prepare_module_output nf-deeptools-heatmap deeptools_heatmap_output
  launch_nf_bg nf-deeptools-heatmap \
    "${MASTER_ARGS[@]}" \
    --chipfilter_output "${PIPELINES_ROOT}/nf-chipfilter/chipfilter_output" \
    --macs3_output "${PIPELINES_ROOT}/nf-macs3/macs3_output" \
    --diffbind_output "${PIPELINES_ROOT}/nf-diffbind/diffbind_output"
else
  echo "[INFO] Skip nf-deeptools-heatmap"
fi

wait_wave "WAVE2"

# ------------------------
# Wave 3: wrap-up sequence
# ------------------------
if should_run result_delivery "${RUN_RESULT_DELIVERY}"; then
  prepare_module_output nf-result-delivery result_delivery_output
  DELIVERY_ARGS=()
  [[ -n "${DELIVERY_TAG:-}" ]] && DELIVERY_ARGS+=(--delivery_tag "$DELIVERY_TAG")
  [[ -n "${DELIVERY_LEVEL:-}" ]] && DELIVERY_ARGS+=(--delivery_level "$DELIVERY_LEVEL")
  run_nf nf-result-delivery "${DELIVERY_ARGS[@]}"
else
  echo "[INFO] Skip nf-result-delivery"
fi

if should_run multiqc "${RUN_MULTIQC}"; then
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
echo "[DONE] End-to-end pipeline finished (safe parallel waves)."
