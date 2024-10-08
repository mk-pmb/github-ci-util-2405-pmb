#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function fmt_markdown_textblock () {
  [ "$#" -ge 1 ] || set -- core
  "$FUNCNAME"__"$@"
  return $?
}


function fmt_markdown_textblock__core () {
  echo
  echo '```'"${FMT:-text}"
  sed -re 's~^\x60~\&#x60;~g;s~^<~\&lt;~g'
  echo '```'
  # echo; echo "trace:$(printf -- ' &larr; `%s`' "${FUNCNAME[@]}")"
  echo
}


function fmt_markdown_textblock__capture_command () {
  "$@" &> >(fmt_markdown_textblock__core); return $?
}


function fmt_markdown_textblock__stepsumm () {
  [ -n "$GITHUB_STEP_SUMMARY" ] || return 0
  fmt_markdown_textblock "$@" >>"$GITHUB_STEP_SUMMARY" || return $?
  ghciu_ensure_stepsumm_size_limit || return $?
}


function ghciu_stepsumm_dump_textblock () {
  fmt_markdown_textblock stepsumm "$@"; return $?
}


function ghciu_stepsumm_dump_file () {
  fmt_markdown_textblock stepsumm details_file "$@"; return $?
}


function fmt_markdown_textblock__details_file () {
  local FILE="$1"; shift
  [ "${FILE:0:1}" != - ] || return 4$(echo E: $FUNCNAME: >&2 \
    "File name must not start with '-' (consider './-…'): $FILE")
  [ -f "$FILE" ] || return 4$(echo E: $FUNCNAME: >&2 \
    "File must be a regular file: $FILE")
  local ARG=
  local TITLE="$FILE"
  while [ "$#" -ge 1 ]; do
    ARG="$1"
    [ "${ARG:0:1}" == - ] || break
    shift
    case "$ARG" in
      -- ) break;;
      --title ) TITLE="$1"; shift;;
      --basename ) TITLE="$(basename -- "$TITLE")";;
      --count-lines | \
      -- ) "$FUNCNAME${ARG//-/_}" "$@" || return $?;;
      * ) echo E: $FUNCNAME: "Unsupported option: $ARG" >&2; return 4;;
    esac
  done
  fmt_markdown_textblock__details "$TITLE" "$@" <"$FILE" || return $?
}


function fmt_markdown_textblock__details_file__count_lines () {
  sleep 1s # Wait for GitHub's file system cache to settle
  local N_LN="$(wc --lines -- "$FILE" | grep -oPe '^\d+')"
  local SIZE="$(du --apparent-size --human-readable -- "$FILE")"
  SIZE="${SIZE%%$'\t'*}"
  # SIZE="${SIZE// /}"
  TITLE+=" ($SIZE bytes, $N_LN lines)"
}


function fmt_markdown_textblock__details () {
  echo
  echo "<details><summary>$1</summary>"
  shift
  fmt_markdown_textblock "$@"
  local RV=$?
  echo "</details>"
  echo
  return "$RV"
}


function ghciu_ensure_stepsumm_size_limit () {
  [ -n "$GITHUB_STEP_SUMMARY" ] || return 0
  local SZ="$(stat -c %s -- "$GITHUB_STEP_SUMMARY")"
  local MAX=1024000
  [ "${SZ:-0}" -gt "$MAX" ] || return 0
  local TMPF="tmp.$$.github_step_summary_too_long.txt"
  echo '⚠ W: `$GITHUB_STEP_SUMMARY` is critically large ('"$(
    du --human-readable -- "$GITHUB_STEP_SUMMARY" | grep -oPe '^\S+'
    ), approaching GitHub's upload limit. &rArr; Cutting it at" \
    "${MAX/%000/k}."$'\n\n' >"$TMPF" || return $?
  head --bytes="$MAX" -- "$GITHUB_STEP_SUMMARY" >>"$TMPF" || return $?
  mv --no-target-directory -- "$TMPF" "$GITHUB_STEP_SUMMARY" || return $?
}






[ "$1" == --lib ] && return 0; fmt_markdown_textblock "$@"; exit $?
