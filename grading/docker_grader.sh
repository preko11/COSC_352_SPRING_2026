#!/usr/bin/env bash

# Automated grader for COSC 352 Project 01 and Project 02 Docker submissions.
# Bash-only implementation using Docker and native CLI tools.

set -u

SCRIPT_PATH="${BASH_SOURCE[0]}"
SCRIPT_DIR="${SCRIPT_PATH%/*}"
if [ "$SCRIPT_DIR" = "$SCRIPT_PATH" ]; then
  SCRIPT_DIR="."
fi
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RUN_ID="run_$$_$RANDOM"
LOG_FILE="${LOG_FILE:-$ROOT_DIR/grading_run_${RUN_ID}.log}"
SUMMARY_CSV="${SUMMARY_CSV:-$ROOT_DIR/grading_summary_${RUN_ID}.csv}"

PROJECT02_INPUT_DIR="$ROOT_DIR/grading/fixtures"
PROJECT02_INPUT_FILE="$ROOT_DIR/grading/fixtures/project02_input.html"
PROJECT02_MIN_DATA_ROWS="${PROJECT02_MIN_DATA_ROWS:-40}"
PROJECT02_MIN_HEADER_HITS="${PROJECT02_MIN_HEADER_HITS:-6}"
PROJECT02_MIN_LANGUAGE_HITS="${PROJECT02_MIN_LANGUAGE_HITS:-10}"
PROJECT02_MAX_HTML_MARKERS="${PROJECT02_MAX_HTML_MARKERS:-5}"

PROJECT01_NAME_INPUT="${PROJECT01_NAME_INPUT:-Ada}"
PROJECT01_ERROR_REGEX='error|usage|no additional|no name|provide|argument|try again'

BUILD_TIMEOUT="${BUILD_TIMEOUT:-180}"
RUN_TIMEOUT="${RUN_TIMEOUT:-60}"

TOTAL_STUDENTS=0
TOTAL_PROJECTS=0
PASS_PROJECTS=0
FAIL_PROJECTS=0
TOTAL_TESTS=0
PASS_TESTS=0
FAIL_TESTS=0
SCRIPT_START_SECONDS=$SECONDS
TIMEOUT_WARNED=0
PROJECT02_LAST_ROW_COUNT=0
PROJECT02_LAST_HEADER_HITS=0
PROJECT02_LAST_LANGUAGE_HITS=0
PROJECT02_LAST_HTML_MARKERS=0
PROJECT02_LAST_HEADER_ROW_PRESENT=0

: >"$LOG_FILE"

now() {
  printf 't+%ss' "$((SECONDS - SCRIPT_START_SECONDS))"
}

log() {
  local message
  message="[$(now)] $*"
  printf '%s\n' "$message"
  printf '%s\n' "$message" >>"$LOG_FILE"
}

show_log_excerpt() {
  local file_path="$1"
  local line_count="$2"
  sed -n "1,${line_count}p" "$file_path" | tee -a "$LOG_FILE"
}

safe_id() {
  printf '%s' "$1" | sed 's/[^A-Za-z0-9_.-]/_/g'
}

normalize_csv() {
  local source_file="$1"
  local output_file="$2"

  sed 's/\r$//' "$source_file" \
    | sed 's/"//g' \
    | sed 's/[[:space:]]*,[[:space:]]*/,/g' \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
    | grep -v '^[[:space:]]*$' >"$output_file"
}

validate_project02_output_file() {
  local source_file="$1"
  local normalized_file="$2"
  local row_count=0
  local header_hits=0
  local language_hits=0
  local html_markers=0
  local header_row_present=0
  local term

  normalize_csv "$source_file" "$normalized_file"

  row_count="$(grep -c ',' "$normalized_file" || true)"

  for term in \
    "language" \
    "original purpose" \
    "imperative" \
    "object-oriented" \
    "functional" \
    "procedural" \
    "generic" \
    "reflective" \
    "other paradigms" \
    "standardized"; do
    if grep -Fqi "$term" "$normalized_file"; then
      header_hits=$((header_hits + 1))
    fi
  done

  for term in \
    "ada" \
    "c++" \
    "c#" \
    "java" \
    "javascript" \
    "python" \
    "go" \
    "rust" \
    "ruby" \
    "swift" \
    "kotlin" \
    "fortran" \
    "perl" \
    "php" \
    "haskell" \
    "lisp"; do
    if grep -Fqi "$term" "$normalized_file"; then
      language_hits=$((language_hits + 1))
    fi
  done

  if grep -Eiq 'language,.*(original purpose|imperative|object-oriented)' "$normalized_file"; then
    header_row_present=1
  fi

  html_markers="$(grep -Eic '<table|<tr|<td|<th|</' "$normalized_file" || true)"

  PROJECT02_LAST_ROW_COUNT="$row_count"
  PROJECT02_LAST_HEADER_HITS="$header_hits"
  PROJECT02_LAST_LANGUAGE_HITS="$language_hits"
  PROJECT02_LAST_HTML_MARKERS="$html_markers"
  PROJECT02_LAST_HEADER_ROW_PRESENT="$header_row_present"

  if [ "$row_count" -ge "$PROJECT02_MIN_DATA_ROWS" ] \
    && [ "$header_hits" -ge "$PROJECT02_MIN_HEADER_HITS" ] \
    && [ "$language_hits" -ge "$PROJECT02_MIN_LANGUAGE_HITS" ] \
    && [ "$header_row_present" -eq 1 ] \
    && [ "$html_markers" -le "$PROJECT02_MAX_HTML_MARKERS" ]; then
    return 0
  fi

  return 1
}

find_dockerfile() {
  local project_dir="$1"
  local candidate=""

  # Preferred: standard Dockerfile names at project root.
  candidate="$(
    find "$project_dir" -maxdepth 1 -type f \( -iname 'dockerfile' -o -iname '*.dockerfile' \) \
      | sort \
      | awk 'NR == 1 { print; exit }'
  )"
  if [ -n "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  # Fallback: standard Dockerfile names nested in the project.
  candidate="$(
    find "$project_dir" -maxdepth 3 -type f \( -iname 'dockerfile' -o -iname '*.dockerfile' \) \
      | sort \
      | awk 'NR == 1 { print; exit }'
  )"
  if [ -n "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  # Last fallback: files named "Docker"/"docker" that still parse as Dockerfiles.
  while IFS= read -r candidate; do
    if grep -Eiq '^[[:space:]]*(FROM|ARG)[[:space:]]' "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(
    find "$project_dir" -maxdepth 3 -type f \( -iname 'docker' -o -iname 'docker.*' \) | sort
  )
}

run_with_timeout() {
  local seconds="$1"
  shift

  if command -v timeout >/dev/null 2>&1; then
    timeout "$seconds" "$@"
  else
    if [ "$TIMEOUT_WARNED" -eq 0 ]; then
      log "WARN: 'timeout' command not found. Commands will run without timeout protection."
      TIMEOUT_WARNED=1
    fi
    "$@"
  fi
}

build_image() {
  local project_dir="$1"
  local dockerfile_path="$2"
  local image_tag="$3"
  local build_log="$4"
  local context_dir

  : >"$build_log"
  context_dir="$(dirname "$dockerfile_path")"

  run_with_timeout "$BUILD_TIMEOUT" docker build -q -f "$dockerfile_path" -t "$image_tag" "$context_dir" >"$build_log" 2>&1
  local build_rc=$?

  if [ "$build_rc" -eq 0 ]; then
    return 0
  fi

  if [ "$context_dir" != "$project_dir" ]; then
    printf '\n---- fallback build context: project root ----\n' >>"$build_log"
    run_with_timeout "$BUILD_TIMEOUT" docker build -q -f "$dockerfile_path" -t "$image_tag" "$project_dir" >>"$build_log" 2>&1
    build_rc=$?
    if [ "$build_rc" -eq 0 ]; then
      return 0
    fi
  fi

  printf '\n---- fallback build context: repo root ----\n' >>"$build_log"
  run_with_timeout "$BUILD_TIMEOUT" docker build -q -f "$dockerfile_path" -t "$image_tag" "$ROOT_DIR" >>"$build_log" 2>&1
  return $?
}

cleanup_container() {
  local container_name="$1"
  if [ -n "$container_name" ]; then
    docker rm -f "$container_name" >/dev/null 2>&1 || true
  fi
}

cleanup_image() {
  local image_tag="$1"
  if [ -n "$image_tag" ]; then
    docker rmi -f "$image_tag" >/dev/null 2>&1 || true
  fi
}

image_entrypoint() {
  local image_tag="$1"
  docker image inspect -f '{{join .Config.Entrypoint " "}}' "$image_tag" 2>/dev/null
}

image_cmd() {
  local image_tag="$1"
  docker image inspect -f '{{join .Config.Cmd " "}}' "$image_tag" 2>/dev/null
}

image_workdir() {
  local image_tag="$1"
  docker image inspect -f '{{.Config.WorkingDir}}' "$image_tag" 2>/dev/null
}

run_container() {
  local image_tag="$1"
  local container_name="$2"
  local run_log="$3"
  local run_arg="$4"
  local mount_input="$5"
  local stdin_mode="$6"
  local stdin_payload="$7"

  local entrypoint
  local cmd
  local -a run_cmd
  local -a cmd_parts

  entrypoint="$(image_entrypoint "$image_tag")"
  cmd="$(image_cmd "$image_tag")"

  run_cmd=(docker run --name "$container_name")

  if [ "$stdin_mode" != "none" ]; then
    run_cmd+=(-i)
  fi

  if [ "$mount_input" -eq 1 ]; then
    run_cmd+=(-v "$PROJECT02_INPUT_DIR:/grader_input:ro")
  fi

  run_cmd+=("$image_tag")

  if [ -n "$run_arg" ]; then
    if [ -n "$entrypoint" ]; then
      run_cmd+=("$run_arg")
    else
      if [ -n "$cmd" ]; then
        read -r -a cmd_parts <<<"$cmd"
        run_cmd=(docker run --name "$container_name")

        if [ "$stdin_mode" != "none" ]; then
          run_cmd+=(-i)
        fi
        if [ "$mount_input" -eq 1 ]; then
          run_cmd+=(-v "$PROJECT02_INPUT_DIR:/grader_input:ro")
        fi

        run_cmd+=("$image_tag")
        run_cmd+=("${cmd_parts[@]}")
        run_cmd+=("$run_arg")
      else
        run_cmd+=("$run_arg")
      fi
    fi
  fi

  if [ "$stdin_mode" = "line" ]; then
    printf '%s\n' "$stdin_payload" | run_with_timeout "$RUN_TIMEOUT" "${run_cmd[@]}" >"$run_log" 2>&1
  elif [ "$stdin_mode" = "raw" ]; then
    printf '%s' "$stdin_payload" | run_with_timeout "$RUN_TIMEOUT" "${run_cmd[@]}" >"$run_log" 2>&1
  else
    run_with_timeout "$RUN_TIMEOUT" "${run_cmd[@]}" >"$run_log" 2>&1
  fi

  return $?
}

collect_csv_candidates() {
  local container_name="$1"
  local image_tag="$2"
  local workdir
  local scan_paths
  local path
  local safe_path
  local destination

  workdir="$(image_workdir "$image_tag")"
  scan_paths="/app /workspace /workdir /hello /hello1 /tmp"

  if [ -n "$workdir" ] && [ "$workdir" != "/" ]; then
    scan_paths="$workdir $scan_paths"
  fi

  for path in $scan_paths; do
    safe_path="$(printf '%s' "$path" | sed 's#[^A-Za-z0-9]#_#g')"
    destination="/tmp/${container_name}_${safe_path}"

    if docker cp "$container_name:$path" "$destination" >/dev/null 2>&1; then
      find "$destination" -type f -name '*.csv'
    fi
  done | sort -u
}

record_result() {
  local student="$1"
  local project="$2"
  local status="$3"
  local score="$4"
  local tests_passed="$5"
  local tests_total="$6"
  local notes="$7"

  local clean_notes
  clean_notes="$(printf '%s' "$notes" | sed 's/,/;/g; s/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//')"
  if [ -z "$clean_notes" ]; then
    clean_notes="none"
  fi

  printf '%s,%s,%s,%s,%s,%s,%s\n' \
    "$student" "$project" "$status" "$score" "$tests_passed" "$tests_total" "$clean_notes" >>"$SUMMARY_CSV"

  TOTAL_PROJECTS=$((TOTAL_PROJECTS + 1))
  TOTAL_TESTS=$((TOTAL_TESTS + tests_total))
  PASS_TESTS=$((PASS_TESTS + tests_passed))
  FAIL_TESTS=$((FAIL_TESTS + tests_total - tests_passed))

  if [ "$status" = "PASS" ]; then
    PASS_PROJECTS=$((PASS_PROJECTS + 1))
  else
    FAIL_PROJECTS=$((FAIL_PROJECTS + 1))
  fi
}

report_test() {
  local student="$1"
  local project="$2"
  local test_name="$3"
  local result="$4"
  local detail="$5"

  if [ "$result" -eq 1 ]; then
    log "[$student][$project] PASS - $test_name - $detail"
  else
    log "[$student][$project] FAIL - $test_name - $detail"
  fi
}

grade_project01() {
  local student="$1"
  local project_dir="$2"

  local project="project01"
  local tests_total=3
  local tests_passed=0
  local score=0
  local notes=""

  local dockerfile_path
  local image_tag
  local build_log
  local build_ok=0

  local run_log_name
  local run_log_noarg
  local container_name
  local student_id

  student_id="$(safe_id "$student")"
  image_tag="grader_${student_id}_p01_${RUN_ID}_$$"
  build_log="/tmp/${image_tag}_build.log"

  dockerfile_path="$(find_dockerfile "$project_dir")"
  if [ -z "$dockerfile_path" ]; then
    report_test "$student" "$project" "dockerfile" 0 "No Dockerfile found in $project_dir"
    notes="$notes missing Dockerfile;"
    record_result "$student" "$project" "FAIL" "$score" "$tests_passed" "$tests_total" "$notes"
    return
  fi

  if build_image "$project_dir" "$dockerfile_path" "$image_tag" "$build_log"; then
    build_ok=1
    tests_passed=$((tests_passed + 1))
    score=$((score + 30))
    report_test "$student" "$project" "build" 1 "Docker image built"
  else
    report_test "$student" "$project" "build" 0 "Build failed (see log snippet below)"
    show_log_excerpt "$build_log" 12
    notes="$notes build failed;"
  fi

  if [ "$build_ok" -eq 1 ]; then
    container_name="grader_${student_id}_p01_name_${RUN_ID}_$$"
    run_log_name="/tmp/${container_name}.log"

    run_container "$image_tag" "$container_name" "$run_log_name" "$PROJECT01_NAME_INPUT" 0 "line" "$PROJECT01_NAME_INPUT"

    if grep -qi "hello" "$run_log_name" && grep -qi "$PROJECT01_NAME_INPUT" "$run_log_name"; then
      tests_passed=$((tests_passed + 1))
      score=$((score + 50))
      report_test "$student" "$project" "known-input-output" 1 "Greeting includes hello + name"
    else
      report_test "$student" "$project" "known-input-output" 0 "Expected hello + name not found"
      notes="$notes greeting validation failed;"
      show_log_excerpt "$run_log_name" 8
    fi
    cleanup_container "$container_name"

    container_name="grader_${student_id}_p01_noarg_${RUN_ID}_$$"
    run_log_noarg="/tmp/${container_name}.log"

    run_container "$image_tag" "$container_name" "$run_log_noarg" "" 0 "none" ""

    if grep -Eqi "$PROJECT01_ERROR_REGEX" "$run_log_noarg"; then
      tests_passed=$((tests_passed + 1))
      score=$((score + 20))
      report_test "$student" "$project" "no-input-handling" 1 "Graceful error/usage message found"
    else
      report_test "$student" "$project" "no-input-handling" 0 "No error/usage message found"
      notes="$notes error-handling check failed;"
      show_log_excerpt "$run_log_noarg" 8
    fi
    cleanup_container "$container_name"
  else
    report_test "$student" "$project" "known-input-output" 0 "Skipped because build failed"
    report_test "$student" "$project" "no-input-handling" 0 "Skipped because build failed"
  fi

  cleanup_image "$image_tag"

  local status="FAIL"
  if [ "$tests_passed" -eq "$tests_total" ]; then
    status="PASS"
  fi

  record_result "$student" "$project" "$status" "$score" "$tests_passed" "$tests_total" "$notes"
}

grade_project02() {
  local student="$1"
  local project_dir="$2"

  local project="project02"
  local tests_total=3
  local tests_passed=0
  local score=0
  local notes=""

  local dockerfile_path
  local image_tag
  local build_log
  local build_ok=0
  local run_ok=0
  local output_ok=0

  local run_log
  local container_name
  local student_id
  local input_arg="/grader_input/project02_input.html"

  local candidate_file
  local candidate_norm
  local matched_source=""
  local combined_candidates
  local candidates_list
  local validation_detail=""

  student_id="$(safe_id "$student")"
  image_tag="grader_${student_id}_p02_${RUN_ID}_$$"
  build_log="/tmp/${image_tag}_build.log"

  dockerfile_path="$(find_dockerfile "$project_dir")"
  if [ -z "$dockerfile_path" ]; then
    report_test "$student" "$project" "dockerfile" 0 "No Dockerfile found in $project_dir"
    notes="$notes missing Dockerfile;"
    record_result "$student" "$project" "FAIL" "$score" "$tests_passed" "$tests_total" "$notes"
    return
  fi

  if build_image "$project_dir" "$dockerfile_path" "$image_tag" "$build_log"; then
    build_ok=1
    tests_passed=$((tests_passed + 1))
    score=$((score + 30))
    report_test "$student" "$project" "build" 1 "Docker image built"
  else
    report_test "$student" "$project" "build" 0 "Build failed (see log snippet below)"
    show_log_excerpt "$build_log" 12
    notes="$notes build failed;"
  fi

  if [ "$build_ok" -eq 1 ]; then
    container_name="grader_${student_id}_p02_run_${RUN_ID}_$$"
    run_log="/tmp/${container_name}.log"

    if run_container "$image_tag" "$container_name" "$run_log" "$input_arg" 1 "none" ""; then
      run_ok=1
      tests_passed=$((tests_passed + 1))
      score=$((score + 20))
      report_test "$student" "$project" "run-with-known-input" 1 "Container ran with provided fixture"
    else
      report_test "$student" "$project" "run-with-known-input" 0 "Container run failed"
      show_log_excerpt "$run_log" 10
      notes="$notes run failed;"
    fi

      if [ "$run_ok" -eq 1 ]; then
      candidates_list="/tmp/${container_name}_csv_candidates.list"
      combined_candidates="/tmp/${container_name}_csv_combined.txt"
      : >"$candidates_list"
      : >"$combined_candidates"

      collect_csv_candidates "$container_name" "$image_tag" >"$candidates_list"

      if [ -s "$candidates_list" ]; then
        while IFS= read -r candidate_file; do
          cat "$candidate_file" >>"$combined_candidates"
          printf '\n' >>"$combined_candidates"
        done <"$candidates_list"

        candidate_norm="/tmp/${container_name}_combined_norm.txt"
        if validate_project02_output_file "$combined_candidates" "$candidate_norm"; then
          output_ok=1
          matched_source="combined-csv-files"
          validation_detail="rows=$PROJECT02_LAST_ROW_COUNT headers=$PROJECT02_LAST_HEADER_HITS languages=$PROJECT02_LAST_LANGUAGE_HITS html_markers=$PROJECT02_LAST_HTML_MARKERS"
        fi
      fi

      if [ "$output_ok" -eq 0 ]; then
        candidate_norm="/tmp/${container_name}_stdout_norm.txt"
        if validate_project02_output_file "$run_log" "$candidate_norm"; then
          output_ok=1
          matched_source="container-stdout"
          validation_detail="rows=$PROJECT02_LAST_ROW_COUNT headers=$PROJECT02_LAST_HEADER_HITS languages=$PROJECT02_LAST_LANGUAGE_HITS html_markers=$PROJECT02_LAST_HTML_MARKERS"
        fi
      fi

      if [ "$output_ok" -eq 1 ]; then
        tests_passed=$((tests_passed + 1))
        score=$((score + 50))
        report_test "$student" "$project" "output-validation" 1 "Output passed rubric from $matched_source ($validation_detail)"
      else
        report_test "$student" "$project" "output-validation" 0 "Output failed rubric (rows=$PROJECT02_LAST_ROW_COUNT headers=$PROJECT02_LAST_HEADER_HITS languages=$PROJECT02_LAST_LANGUAGE_HITS header_row=$PROJECT02_LAST_HEADER_ROW_PRESENT html_markers=$PROJECT02_LAST_HTML_MARKERS)"
        notes="$notes output validation failed;"
      fi
    else
      report_test "$student" "$project" "output-validation" 0 "Skipped because run failed"
    fi

    cleanup_container "$container_name"
  else
    report_test "$student" "$project" "run-with-known-input" 0 "Skipped because build failed"
    report_test "$student" "$project" "output-validation" 0 "Skipped because build failed"
  fi

  cleanup_image "$image_tag"

  local status="FAIL"
  if [ "$tests_passed" -eq "$tests_total" ]; then
    status="PASS"
  fi

  record_result "$student" "$project" "$status" "$score" "$tests_passed" "$tests_total" "$notes"
}

discover_student_dirs() {
  find "$ROOT_DIR" -mindepth 1 -maxdepth 1 -type d ! -name '.git' ! -name 'grading' ! -name '.*' | sort
}

print_final_summary() {
  log "================ Final Summary ================"
  log "Students graded: $TOTAL_STUDENTS"
  log "Projects graded: $TOTAL_PROJECTS"
  log "Projects passed: $PASS_PROJECTS"
  log "Projects failed: $FAIL_PROJECTS"
  log "Tests passed: $PASS_TESTS / $TOTAL_TESTS"
  log "Summary CSV: $SUMMARY_CSV"
  log "Run log: $LOG_FILE"
  printf '\n'
  printf 'Per-student totals:\n'
  awk -F',' '
    NR > 1 {
      score[$1] += $4
      max[$1] += 100
      pass[$1] += ($3 == "PASS")
      total[$1] += 1
    }
    END {
      for (s in score) {
        printf "%s: %d/%d (%d/%d projects passed)\n", s, score[s], max[s], pass[s], total[s]
      }
    }
  ' "$SUMMARY_CSV" | sort
}

main() {
  local student_filter="${1:-}"
  local student_dir
  local student_name

  if ! docker --version >/dev/null 2>&1; then
    log "ERROR: Docker is not available."
    return 1
  fi

  if ! docker info >/dev/null 2>&1; then
    log "ERROR: Docker daemon is not reachable. Start Docker and rerun."
    return 1
  fi

  if [ ! -f "$PROJECT02_INPUT_FILE" ]; then
    log "ERROR: Missing Project 02 input fixture: $PROJECT02_INPUT_FILE"
    return 1
  fi

  printf 'student,project,status,score,tests_passed,tests_total,notes\n' >"$SUMMARY_CSV"

  log "Starting automated grading run: $RUN_ID"
  log "Root directory: $ROOT_DIR"
  log "Project01 known input: $PROJECT01_NAME_INPUT"
  log "Project02 known input file: $PROJECT02_INPUT_FILE"

  while IFS= read -r student_dir; do
    student_name="${student_dir##*/}"

    if [ -n "$student_filter" ]; then
      if ! printf '%s' "$student_name" | grep -Eq "$student_filter"; then
        continue
      fi
    fi

    if [ ! -d "$student_dir/project01" ] && [ ! -d "$student_dir/project02" ]; then
      continue
    fi

    TOTAL_STUDENTS=$((TOTAL_STUDENTS + 1))
    log "------------ Grading student: $student_name ------------"

    if [ -d "$student_dir/project01" ]; then
      grade_project01 "$student_name" "$student_dir/project01"
    else
      log "[$student_name][project01] Skipped (directory missing)"
    fi

    if [ -d "$student_dir/project02" ]; then
      grade_project02 "$student_name" "$student_dir/project02"
    else
      log "[$student_name][project02] Skipped (directory missing)"
    fi
  done < <(discover_student_dirs)

  print_final_summary
}

main "$@"
