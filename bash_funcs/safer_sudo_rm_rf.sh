#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function safer_sudo_rm_rf () {
  local ARG= ABS=
  if [ "$1" == --stopwatch ]; then
    shift
    log_rtc_stopwatch 0 "$1"
    shift
    ABS=$SECONDS
    safer_sudo_rm_rf --skip-missing "$@" || return $?
    log_rtc_stopwatch $SECONDS+1-$ABS 'done. took ≤ ¤ sec.'
    return 0
  fi
  local OPT_SKIP_MISS=
  local OPT_VERBOSE=
  local RM='sudo rm --preserve-root=all --one-file-system'
  for ARG in "$@"; do
    case "$ARG" in
      -v | --verbose ) OPT_VERBOSE='--verbose'; continue;;
      --skip-missing ) OPT_SKIP_MISS='+'; continue;;
      -* ) echo E: $FUNCNAME: "Unsupported option: $ARG" >&2; return 4;;
    esac
    if sudo test -L "$ARG"; then
      safer_sudo_rm_rf__decide_path "$ARG" --rel-ok || return 4$(
        echo E: $FUNCNAME: "Flinching from removing symlink '$ARG'." >&2)
      sudo ls -l -- "$ARG"
      $RM $OPT_VERBOSE -- "$ARG" || return 4$(
        echo E: $FUNCNAME: "Failed to rm symlink: $ARG" >&2)
      continue
    fi
    [ -n "$OPT_SKIP_MISS" ] && sudo test ! -e "$ARG" && continue
    safer_sudo_rm_rf__decide_path "$ARG" --rel-ok || return 4$(
      echo E: $FUNCNAME: "Flinching from removing '$ARG'." >&2)
    ABS="$(readlink -m -- "$ARG")"
    [ -n "$ABS" ] || return 4$(
      echo E: $FUNCNAME: "Failed to find absolute path for: $ARG" >&2)
    safer_sudo_rm_rf__decide_path "$ABS" || return 4$(
      echo E: $FUNCNAME: "Flinching from removing '$ARG'" \
        "because it points to '$ABS'." >&2)
    $RM $OPT_VERBOSE --recursive -- "$ARG" || return $?
  done
}


function safer_sudo_rm_rf__decide_path () {
  case "$1" in
    ./* | ../* | [A-Za-z0-9_]* ) [ "$2" == --rel-ok ]; return $?;;
    /target ) ;;
    /[^/]*/[^/]* ) ;;
    * ) return 1;;
  esac
}








[ "$1" == --lib ] && return 0; safer_sudo_rm_rf "$@"; exit $?
