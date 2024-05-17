#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function ghciu_stepsumm_dump_textblock () {
  [ -n "$GITHUB_STEP_SUMMARY" ] || return 0
  ( echo
    echo '```'"$FMT"
    sed -re '/^\x60{3}/s~^.~\&#96;~'
    echo '```'
    echo
  ) >>"$GITHUB_STEP_SUMMARY" || return $?
}


[ "$1" == --lib ] && return 0; ghciu_stepsumm_dump_textblock "$@"; exit $?
