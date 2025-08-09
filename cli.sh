#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function ghciu_cli_main () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local DBGLV="${DEBUGLEVEL:-0}"
  local GHCIU_DIR="$(readlink -m -- "$BASH_SOURCE"/..)"
  local CI_INVOKED_IN="$PWD"
  local CI_FUNCD="$GHCIU_DIR/bash_funcs"
  local CI_PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  case "$1" in
    --print-ghciu-dir ) echo "$GHCIU_DIR"; return $?;;
    --print-funcs-dir ) echo "$CI_FUNCD"; return $?;;
  esac

  local -A CFG=() MEM=( [start_uts]="$EPOCHSECONDS" )
  CFG[task_done_report_file]='/dev/stdout'
  source -- "$CI_FUNCD"/ci_cli_init.sh || return $?
  source_these_files --lib "$CI_FUNCD"/*.sh || return $?
  source_additional_bash_funcs_files --had="$GHCIU_DIR" \
    "$CI_PROJECT_DIR" \
    . || return $?
  ghciu_cli_init_before_config || return $?

  [ "$1" != . ] || while shift && [ "$#" -ge 1 ]; do case "$1" in
    . ) shift; break;;
    *=* ) CFG["${1%%=*}"]="${1#*=}";;
    * ) echo source_these_files --ci-dot "$1" || return $?;;
  esac; done

  local CI_LOG=
  if [ "$1" == --no-log ]; then shift; CI_LOG='/dev/null'; fi
  if [ "$1" == --succeed-quietly ]; then
    CFG[task_done_report_file]=/dev/null
    shift
  fi

  local CI_TASK="$1"; shift
  [ -n "$CI_TASK" ] || CI_TASK="${CFG[default_task]}"
  [ -n "$CI_TASK" ] || CI_TASK='default_task'
  case "$CI_TASK" in
    '' ) ;;
    ghciu+s://* | \
    proj+s://* | \
    '' ) set -- . "${CI_TASK/+s/}" "$@"; CI_TASK='chdir_relative_and_source';;
  esac
  case "$CI_TASK" in
    ghciu://* ) CI_TASK="$GHCIU_DIR${CI_TASK#*/}";;
    proj://* ) CI_TASK="$CI_PROJECT_DIR${CI_TASK#*/}";;
  esac
  [ "$(type -t "ghciu_$CI_TASK")" == function ] && CI_TASK="ghciu_$CI_TASK"

  [ -n "$CI_LOG" ] || CI_LOG="$(ghciu_decide_logfile_name "$CI_TASK"
    )" || return $?$(echo E: "Failed to decide logfile destination!" >&2)
  mkdir --parents -- "$(dirname -- "$CI_LOG")"
  >>"$CI_LOG" || return $?$(echo E: "Cannot write to CI log: $CI_LOG" >&2)

  export CI_FUNCD
  export CI_INVOKED_IN
  export CI_LOG
  export CI_PROJECT_DIR
  export CI_TASK
  export GHCIU_DIR

  ghciu_magic_cilog_tee "$CI_LOG" "$CI_TASK" "$@" &
  wait "$!"
  local RV=$?
  wait # … for tee to finish writing
  sleep 0.2s # wait a bit more for tee output to flush
  cd -- "$CI_INVOKED_IN" || echo W: >&2 \
    "Failed to chdir back to our original working directory:" \
    "$CI_INVOKED_IN — this will probably mess with logging."
  if [ "$RV" == 0 ]; then
    RV="D: Task done:$(printf ' ‹%s›' "$CI_TASK" "$@")"
    echo "$RV" >>"$CI_LOG"
    echo "$RV" >>"${CFG[task_done_report_file]}"
    # ^-- We cannot use tee because depending on whether
    #     CFG[task_done_report_file] is /dev/stdout we'd need to either
    #     omit it from the tee arguments or mute tee's default output.
    ghciu_ensure_stepsumm_size_limit || return $?
    return 0
  fi
  local FAIL_REPORT="E: Task failed (rv=$RV):$(
    printf ' ‹%s›' "$CI_TASK" "$@")"
  echo "$FAIL_REPORT" >&2
  echo "$FAIL_REPORT" >>"$CI_LOG"

  if [ -z "$GITHUB_STEP_SUMMARY" ]; then
    true
  elif [[ "$CI_LOG" == /dev/* ]]; then
    true
  elif [ -f "$CI_LOG" ]; then
    ci_fail_log_summary
  fi

  return "$RV"
}


ghciu_cli_main "$@"; exit $?
