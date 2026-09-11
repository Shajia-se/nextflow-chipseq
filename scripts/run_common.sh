#!/usr/bin/env bash
# Sourced by both launchers after reading the user's env.
LAYOUT_HELPER="${ROOT_DIR}/scripts/run_layout.py"
command -v python3 >/dev/null || { echo 'ERROR: python3 is required'; exit 1; }
command -v nextflow >/dev/null || { echo 'ERROR: nextflow is not on PATH'; exit 1; }
PIPELINES_ROOT="${PIPELINES_ROOT:-$(cd "${ROOT_DIR}/.." && pwd)}"
CHIP_RUNS_ROOT="${CHIP_RUNS_ROOT:-${PIPELINES_ROOT}/chip_runs}"
RUNNER="${RUNNER:-${USER:-user}}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d_%H%M%S)_${RUNNER}}"
ENV_FILE="$(cd "$(dirname "$ENV_FILE")" && pwd)/$(basename "$ENV_FILE")"
layout_vars="$(python3 "$LAYOUT_HELPER" init --code "$PIPELINES_ROOT" --runs "$CHIP_RUNS_ROOT" \
  --run-id "$RUN_ID" --env "$ENV_FILE" --owner "$$" --legacy "${OUTPUT_PROJECT_ROOT:-}")" || exit 1
eval "$layout_vars"
unset layout_vars
layout_finish () {
  local result=$?
  trap - EXIT
  python3 "$LAYOUT_HELPER" finish --record "$RECORD_DIR" --run "$ACTIVE_RUN_ROOT" --owner "$$" --exit-code "$result" || true
  exit "$result"
}
layout_cancel () {
  local pid
  for pid in $(jobs -pr); do kill -TERM "$pid" 2>/dev/null || true; done
  wait || true
  exit 130
}
trap layout_finish EXIT
trap layout_cancel INT TERM

run_nf () {
  local module="$1"
  shift
  python3 "$LAYOUT_HELPER" module --code "$PIPELINES_ROOT" --run "$ACTIVE_RUN_ROOT" \
    --record "$RECORD_DIR" --module "$module" --profile "$PROFILE" --mail "$HPC_MAIL_USER" \
    --resume "${RESUME:-true}" --config "${NEXTFLOW_CONFIG:-}" -- "$@" 2>&1 | tee "${LOG_DIR}/${module}.console.log"
}

launch_nf_bg () {
  local module="$1"
  shift
  python3 "$LAYOUT_HELPER" module --code "$PIPELINES_ROOT" --run "$ACTIVE_RUN_ROOT" \
    --record "$RECORD_DIR" --module "$module" --profile "$PROFILE" --mail "$HPC_MAIL_USER" \
    --resume "${RESUME:-true}" --config "${NEXTFLOW_CONFIG:-}" -- "$@" >"${LOG_DIR}/${module}.console.log" 2>&1 &
  PIDS+=("$!")
  NAMES+=("$module")
  echo "[INFO] Launched ${module}; log=${LOG_DIR}/${module}.console.log"
}
