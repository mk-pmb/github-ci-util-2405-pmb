#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function vdo () {
  local VDO_DURA="-$EPOCHSECONDS"
  local VDO_TEE_FD= VDO_TEE_PID=
  exec {VDO_TEE_FD}> >(exec -a vdo-tee-log tee -- $VDO_TEE_LOG)
  VDO_TEE_PID=$!

  local VDO_CMD_EXEC='exec'
  local VDO_CMD_PRE=()
  local VDO_WATCHDOG_CMD= VDO_WATCHDOG_PID=
  while [ "$#" -ge 1 ]; do case "$1" in
    --timeout=* ) VDO_CMD_PRE+=( timeout "${1#*=}" ); shift;;
    --watchdog=* ) VDO_WATCHDOG_CMD="${1#*=}"; shift;;
    -- ) shift; break;;
    -* ) echo E: $FUNCNAME: "Unsupported option: $1" >&2; return 4;;
    * ) break;;
  esac; done

  local VDO_DESCR="$*"' '
  while true; do case "$VDO_DESCR" in
    *'  '* ) VDO_DESCR="${VDO_DESCR//  / }";;
    'sudo -E '* ) VDO_DESCR="${VDO_DESCR/ -E / }";;
    'sudo ' | 'sudo '[^-]* | \
    'eval '* | \
    ' '* ) VDO_DESCR="${VDO_DESCR#* }";;
    * ) break;;
  esac; done
  VDO_DESCR="${VDO_DESCR% }"
  [ -n "$VDO_DESCR" ] || return 0
  [ "${#VDO_DESCR}" -lt 70 ] || VDO_DESCR="${VDO_DESCR:0:70}…"
  vdo__cutline "# >>--->> $VDO_DESCR >>---" - '>>' 120

  case "$(type -t "$1")" in
    builtin | function ) VDO_CMD_EXEC=;;
  esac
  $VDO_CMD_EXEC "${VDO_CMD_PRE[@]}" "$@" >&"$VDO_TEE_FD" 2>&1 &
  local VDO_CMD_PID=$!

  if [ -n "$VDO_WATCHDOG_CMD" ]; then
    eval "$VDO_WATCHDOG_CMD" &
    VDO_WATCHDOG_PID=$!
  fi

  wait "$VDO_CMD_PID"
  local VDO_CMD_RV="$?"
  (( VDO_DURA += EPOCHSECONDS ))

  exec {VDO_TEE_FD}<&-
  wait "$VDO_TEE_PID"
  local VDO_TEE_RV=$?
  sleep 0.2s # Wait for log tee to settle

  [ "$VDO_TEE_RV" == 0 ] || echo E: $FUNCNAME: >&2 \
    "Log tee failed, rv=$VDO_TEE_RV"

  [ -z "$VDO_WATCHDOG_PID" ] || wait "$VDO_WATCHDOG_PID"
  local VDO_WATCHDOG_RV=$?
  [ "$VDO_WATCHDOG_RV" == 0 ] || echo E: $FUNCNAME: >&2 \
    "Watchdog failed, rv=$VDO_WATCHDOG_RV"
  VDO_DESCR+=", rv=$VDO_CMD_RV, took $VDO_DURA sec"
  vdo__cutline "# <<---<< $VDO_DESCR <<---" - '<<' 120
  echo
  return $(( VDO_CMD_RV + VDO_TEE_RV + VDO_WATCHDOG_RV ))
}


function vdo__cutline () {
  local HEAD="$1"; shift
  local FILL="$1"; shift
  local TAIL="$1"; shift
  local MIN_WIDTH="$1"; shift
  local PAD= MISS=
  let MISS="$MIN_WIDTH - ${#HEAD} - ${#TAIL}"
  if [ "$MISS" -ge 1 ]; then
    printf -v PAD -- '% *s' "$MISS" ''
    PAD="${PAD// /$FILL}"
    PAD="${PAD:0:$MISS}"
  fi
  echo "$HEAD$PAD$TAIL"
}




[ "$1" == --lib ] && return 0; vdo "$@"; exit $?
