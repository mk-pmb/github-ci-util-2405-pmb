#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function ghciu_cli_main () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local GHCIU_DIR="$(readlink -m -- "$BASH_SOURCE"/..)"
  local DBGLV="${DEBUGLEVEL:-0}"
  local CI_FUNCD="$GHCIU_DIR/bash_funcs"
  case "$#:$*" in
    1:--print-ghciu-dir ) echo "$GHCIU_DIR"; return $?;;
    1:--print-funcs-dir ) echo "$CI_FUNCD"; return $?;;
  esac

  local -A CFG=() MEM=( [start_uts]="$EPOCHSECONDS" )
  CFG[task_done_report_file]='/dev/stdout'
  source -- "$CI_FUNCD"/ci_cli_init.sh || return $?
  source_these_files --lib "$CI_FUNCD"/*.sh || return $?
  [ . -ef "$GHCIU_DIR" ] || \
    source_these_files --lib {bash_,}funcs/*.sh || return $?
  ghciu_cli_init_before_config || return $?

  [ "$1" != . ] || while shift && [ "$#" -ge 1 ]; do case "$1" in
    . ) shift; break;;
    *=* ) CFG["${1%%=*}"]="${1#*=}";;
    * ) echo source_these_files --ci-dot "$1" || return $?;;
  esac; done

  if [ "$1" == --no-log ]; then shift; "$@"; return $?; fi
  if [ "$1" == --succeed-quietly ]; then
    CFG[task_done_report_file]=/dev/null
    shift
  fi
  local CI_TASK="$1"; shift
  [ -n "$CI_TASK" ] || CI_TASK="${CFG[default_task]}"
  [ -n "$CI_TASK" ] || CI_TASK='default_task'
  [ "$(type -t "ghciu_$CI_TASK")" == function ] && CI_TASK="ghciu_$CI_TASK"

  local CI_LOGS_PREFIX=
  for CI_LOGS_PREFIX in "@$HOSTNAME" local; do
    for CI_LOGS_PREFIX in {.ghciu/,,tmp.}logs."$CI_LOGS_PREFIX"/; do
      [ -d "$CI_LOGS_PREFIX" ] && break 2
    done
  done
  if [ ! -d "$CI_LOGS_PREFIX" ]; then
    CI_LOGS_PREFIX='.ghciu/logs.local/'
    mkdir --parents -- "$CI_LOGS_PREFIX"
  fi
  local CI_LOG="$CI_LOGS_PREFIX$(basename -- "$CI_TASK" .sh).log"
  >>"$CI_LOG" || return $?$(echo E: "Cannot write to CI log: $CI_LOG" >&2)

  "$CI_TASK" "$@" &> >(tee -- "$CI_LOG")
  local RV=$?
  wait # … for tee to finish writing
  sleep 0.2s # wait a bit more for tee output to flush
  if [ "$RV" == 0 ]; then
    RV="D: Task done:$(printf ' ‹%s›' "$CI_TASK" "$@")"
    echo "$RV" >>"$CI_LOG"
    echo "$RV" >>"${CFG[task_done_report_file]}"
    # ^-- We cannot use tee because depending on whether
    #     CFG[task_done_report_file] is /dev/stdout we'd need to either
    #     omit it from the tee arguments or mute tee's default output.
    return 0
  fi
  <<<"E: Task failed (rv=$RV):$(printf ' ‹%s›' "$CI_TASK" "$@"
    )" tee --append -- "$CI_LOG" >&2

  # v-- The `uniq` is to tame node.js's `CallSite {},` spam.
  tail --bytes=4K -- "$CI_LOG" | uniq | tail --lines=20 \
    | ghciu_stepsumm_dump_textblock

  return "$RV"
}


ghciu_cli_main "$@"; exit $?
