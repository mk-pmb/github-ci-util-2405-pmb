#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function ghciu_cli_main () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local GHCIU_DIR="$(readlink -m -- "$BASH_SOURCE"/..)"
  local DBGLV="${DEBUGLEVEL:-0}"
  local -A CFG=() MEM=( [start_uts]="$EPOCHSECONDS" )
  local CI_FUNCD="$GHCIU_DIR/bash_funcs"
  source -- "$CI_FUNCD"/ci_cli_init.sh || return $?
  source_these_files --lib "$CI_FUNCD"/*.sh || return $?
  [ . -ef "$GHCIU_DIR" ] || \
    source_these_files --lib {bash_,}funcs/*.sh || return $?
  ghciu_cli_init_before_config || return $?

  if [ "$1" == . ]; then
    shift
    while [ "$1" != '.' ]; do
      source_these_files --ci-dot "$1" || return $?
      shift
    done
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
    <<<"D: Task done:$(printf ' ‹%s›' "$CI_TASK" "$@"
      )" tee --append -- "$CI_LOG"
    return 0
  fi
  <<<"E: Task failed (rv=$RV):$(printf ' ‹%s›' "$CI_TASK" "$@"
    )" tee --append -- "$CI_LOG" >&2
  tail --lines=20 -- "$CI_LOG" | ghciu_stepsumm_dump_textblock
  return "$RV"
}


ghciu_cli_main "$@"; exit $?
