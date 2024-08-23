#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function ghciu_stepsumm_dump_textblock () {
  [ -n "$GITHUB_STEP_SUMMARY" ] || return 0
  ( echo
    echo '```'"${FMT:-text}"
    sed -re 's~^\x60~\&#x60;~g;s~^<~\&lt;~g'
    echo '```'
    echo
  ) >>"$GITHUB_STEP_SUMMARY" || return $?
  ghciu_ensure_stepsumm_size_limit || return $?
}


function ghciu_ensure_stepsumm_size_limit () {
  local SZ="$(stat -c %s -- "$GITHUB_STEP_SUMMARY")"
  local MAX=1024000
  [ "${SZ:-0}" -gt "$MAX" ] || return 0
  echo '⚠ W: `$GITHUB_STEP_SUMMARY` is critically large'"$(
    du --human-readable -- "$GITHUB_STEP_SUMMARY" | grep -oPe '^\S+'
    ), approaching GitHub's upload limit. &rArr; Cutting it at"
    "${MAX/%000/k}."$'\n\n' | sed -e '1r-' -i -- "$GITHUB_STEP_SUMMARY"
  truncate --size="$MAX" -- "$GITHUB_STEP_SUMMARY" || return $?
}


[ "$1" == --lib ] && return 0; ghciu_stepsumm_dump_textblock "$@"; exit $?
