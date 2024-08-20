#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function watchdog_slow_child () {
  local CH_PID="$1"; shift
  local MUTE_UNTIL="$1"; shift
  local CH_DESCR="${1:-Process $CH_PID}"; shift
  local MUTE_INTV="$MUTE_UNTIL"
  case "$MUTE_UNTIL" in
    [0-9]*+[0-9]* ) # initial + again_interval
      MUTE_INTV="${MUTE_UNTIL##*+}"
      MUTE_UNTIL="${MUTE_UNTIL%%+*}"
      ;;
  esac
  [ "${MUTE_INTV:-0}" -ge 1 ] || return 4$(
    echo E: $FUNCNAME: "Check interval (seconds) must be positive!" >&2)

  [ "${CH_PID:-0}" -ge 2 ] || return 4$(
    echo E: $FUNCNAME: "Child process ID must be >= 2" >&2)
  local CH_PGID="$(ps ho pgid "$CH_PID")"
  [ "${CH_PGID:-0}" -ge 1 ] || return 4$(echo E: $FUNCNAME: >&2 \
    "Cannot find process group ID for child process pid $CH_PID. Stillborn?")

  SECONDS=0
  while sleep 0.2s && kill -0 "$CH_PID" 2>/dev/null; do
    [ "$SECONDS" -ge "$MUTE_UNTIL" ] || continue
    (( MUTE_UNTIL += MUTE_INTV ))
    echo W: $FUNCNAME: "$CH_DESCR is still busy after $SECONDS seconds!" >&2
    ps o user,pid,ppid,pgid,args -"$CH_PGID"
  done
}


[ "$1" == --lib ] && return 0; watchdog_slow_child "$@"; exit $?
