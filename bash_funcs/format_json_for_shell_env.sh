#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function format_json_for_shell_env () {
  local -A CFG=(
    [wrap_val]="'"
    [out_file]='/dev/stdout'
    )
  local ARG= OPT=
  while [ "$#" -ge 1 ]; do
    ARG="$1"; shift
    case "$ARG" in
      --ghenv ) CFG[wrap_val]=; CFG[out_file]="$GITHUB_ENV";;
      --ghout ) CFG[wrap_val]=; CFG[out_file]="$GITHUB_OUTPUT";;
      -* ) echo E: $FUNCNAME: "Unsupported option: $1" >&2; return 4;;
      * )
        OPT="${ARG%=*}"
        ARG="${ARG##*=}"
        eval "ARG=\"\$$ARG\""
        ARG="${ARG//$'\n'/}"
        ARG="${ARG//$'\r'/}"
        ARG="${ARG//\$/\u0024}"
        ARG="${ARG//\`/\u0060}"
        ARG="${ARG//\'/\u0027}"
        echo "$OPT=${CFG[wrap_val]}$ARG${CFG[wrap_val]}" >>"${CFG[out_file]}" \
          || return 4$(echo E: "Failed to write to ${CFG[out_file]}" >&2)
        ;;
    esac
  done
}


[ "$1" == --lib ] && return 0; format_json_for_shell_env "$@"; exit $?
