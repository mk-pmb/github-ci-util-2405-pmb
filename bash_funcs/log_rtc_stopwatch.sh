#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function log_rtc_stopwatch () {
  local DURA=
  let DURA="$1"; shift
  local MSG="$*"
  local PRE=
  if [[ "$MSG" == ': '* ]]; then
    PRE="${FUNCNAME[1]}"
    PRE="${PRE//__/: }"
    PRE="${PRE//_/ }"
    MSG="$PRE$MSG"
  fi
  MSG="${MSG//¤/$DURA}"
  printf 'T: [%(%F %T)T] %s\n' -1 "$MSG"
}

return 0
