#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function tally_files_list_directory_weights () {
  local MIN_DEPTH="${TALLY_MIN_DEPTH:-0}"
  [ "$MIN_DEPTH" -ge 1 ] || MIN_DEPTH=1
  local -A TALLY=()
  local KEY= VAL= ORIG_LINE_WEIGHT= DEPTH=
  local PARTS=()
  while IFS= read -r KEY; do
    let ORIG_LINE_WEIGHT="${#KEY} + 1"
    while [[ "$KEY" == */ ]]; do KEY="${KEY%/}"; done
    while [[ "$KEY" == /* ]]; do KEY="${KEY#/}"; done
    PARTS=()
    readarray -t PARTS <<<"${KEY//'/'/$'\n'}"
    [ "${#PARTS[@]}" -ge 1 ] || continue
    DEPTH=0
    KEY=
    for VAL in "${PARTS[@]}"; do
      [ -z "$KEY" ] || KEY+='/'
      KEY+="$VAL"
      (( DEPTH += 1 ))
      [ "$DEPTH" -lt "$MIN_DEPTH" ] && continue
      VAL="${TALLY[:$KEY]}"
      (( VAL += ORIG_LINE_WEIGHT ))
      TALLY[":$KEY"]="$VAL"
    done
  done
  for KEY in "${!TALLY[@]}"; do
    echo "${TALLY[$KEY]}"$'\t'"${KEY#:}"
  done | sort --general-numeric-sort --reverse
}










tally_files_list_directory_weights "$@"; exit $?
