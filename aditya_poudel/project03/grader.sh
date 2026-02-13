#!/usr/bin/env bash
set -u

############################################################
# COSC 352 - Project03
# Bash-only Docker grader for project01 + project02
# Works without changing student Dockerfiles or code
############################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

LOG_FILE="$SCRIPT_DIR/grading_$(date +%Y%m%d_%H%M%S).log"

PROJECTS=("project01" "project02")
TIME_LIMIT=20

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_TESTS=0

# -------- logging --------
log() { echo "$1" | tee -a "$LOG_FILE"; }

# -------- normalize helpers --------
normalize_stream() { sed 's/\r//g' | sed 's/[[:space:]]*$//'; }
normalize_file() { normalize_stream < "$1"; }

# -------- portable timeout wrapper --------
# usage: run_with_timeout <seconds> <command...>
run_with_timeout() {
  local secs="$1"; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$secs" "$@"
  else
    # No timeout available (common on macOS without coreutils)
    "$@"
  fi
}

# -------- docker cleanup --------
cleanup_container() { docker rm -f "$1" >/dev/null 2>&1 || true; }
cleanup_image() { docker rmi -f "$1" >/dev/null 2>&1 || true; }

############################################################
# Project01 test: "Hello World <name>" via CLI arg
############################################################
run_test_project01() {
  local image="$1"
  local expected="Hello World Aditya"

  log "Running Project01 Test..."

  # capture stdout+stderr to help debugging, then normalize
  local raw
  raw="$(run_with_timeout "$TIME_LIMIT" docker run --rm "$image" Aditya 2>&1 || true)"
  local actual
  actual="$(echo "$raw" | normalize_stream)"

  log "DEBUG Raw Output: $raw"

  if [[ "$actual" == "$expected" ]]; then
    log "✅ Project01 PASS"
    ((PASS_COUNT++))
  else
    log "❌ Project01 FAIL"
    log "Expected: $expected"
    log "Actual:   $actual"
    ((FAIL_COUNT++))
  fi

  ((TOTAL_TESTS++))
}

############################################################
# Project02 test: read HTML, produce CSV
# We do NOT require stdout CSV.
# We copy CSV file out (table_1.csv or output.csv), compare content.
############################################################
run_test_project02() {
  local image="$1"
  local container="p2_${RANDOM}_$$"

  local TEST_HTML="$SCRIPT_DIR/testdata/sample.html"
  local EXPECTED_CSV="$SCRIPT_DIR/testdata/expected_table.csv"
  local TMP_OUT="$SCRIPT_DIR/tmp_${container}.csv"

  log "Running Project02 Test..."

  # Start container (detached) so we can docker cp files out
  # Mount input at /app/input.html (WORKDIR /app in your Dockerfile)
  docker run -d --name "$container" \
    -v "$TEST_HTML":/app/input.html \
    "$image" input.html >/dev/null 2>&1

  # Give it a moment (no python in grader, just wait a bit)
  sleep 3

  # Try common output file names (based on your observed log)
  rm -f "$TMP_OUT" >/dev/null 2>&1 || true

  docker cp "$container":/app/table_1.csv "$TMP_OUT" >/dev/null 2>&1 || true
  if [[ ! -s "$TMP_OUT" ]]; then
    docker cp "$container":/app/output.csv "$TMP_OUT" >/dev/null 2>&1 || true
  fi

  # Grab logs for reporting (but we won't grade on logs)
  local logs
  logs="$(docker logs "$container" 2>&1 | normalize_stream)"

  cleanup_container "$container"

  if [[ -s "$TMP_OUT" ]]; then
    # Compare normalized file contents
    local expected actual
    expected="$(normalize_file "$EXPECTED_CSV")"
    actual="$(normalize_file "$TMP_OUT")"
    rm -f "$TMP_OUT" >/dev/null 2>&1 || true

    if diff <(echo "$expected") <(echo "$actual") >/dev/null; then
      log "✅ Project02 PASS"
      ((PASS_COUNT++))
    else
      log "❌ Project02 FAIL"
      log "Logs:"
      echo "$logs" | tee -a "$LOG_FILE"
      log "Expected CSV:"
      echo "$expected" | tee -a "$LOG_FILE"
      log "Actual CSV:"
      echo "$actual" | tee -a "$LOG_FILE"
      ((FAIL_COUNT++))
    fi
  else
    # No CSV file found inside container
    log "❌ Project02 FAIL"
    log "Reason: No /app/table_1.csv or /app/output.csv found in container."
    log "Logs:"
    echo "$logs" | tee -a "$LOG_FILE"
    ((FAIL_COUNT++))
  fi

  ((TOTAL_TESTS++))
}

############################################################
# MAIN LOOP: grade all student dirs
# (you said you don't want to skip your own — so we grade everyone incl. aditya_poudel)
############################################################
log "Repository Root: $REPO_ROOT"
log "Log File: $LOG_FILE"
log "--------------------------------------------"

for student_dir in "$REPO_ROOT"/*; do
  [[ -d "$student_dir" ]] || continue
  student="$(basename "$student_dir")"

  log ""
  log "============================================"
  log "Grading Student: $student"
  log "============================================"

  for project in "${PROJECTS[@]}"; do
    project_path="$student_dir/$project"

    if [[ ! -d "$project_path" ]]; then
      log "⚠️  $project not found"
      continue
    fi

    image_name="${student}_${project}_image"

    log ""
    log "Building $project..."
    if docker build -t "$image_name" "$project_path" >>"$LOG_FILE" 2>&1; then
      log "Build SUCCESS"
    else
      log "Build FAILED"
      ((FAIL_COUNT++))
      ((TOTAL_TESTS++))
      continue
    fi

    case "$project" in
      project01) run_test_project01 "$image_name" ;;
      project02) run_test_project02 "$image_name" ;;
    esac

    cleanup_image "$image_name"
  done
done

############################################################
# SUMMARY
############################################################
log ""
log "============================================"
log "FINAL SUMMARY"
log "============================================"
log "Total Tests: $TOTAL_TESTS"
log "Passed:      $PASS_COUNT"
log "Failed:      $FAIL_COUNT"

if [[ $TOTAL_TESTS -gt 0 ]]; then
  score=$((PASS_COUNT * 100 / TOTAL_TESTS))
  log "Overall Score: $score%"
fi

log "Grading Complete."
