#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function ghciu_cli_init_before_config () {
  local ITEM= ADD=
  for ITEM in "$PWD"/node_modules/.bin/; do
    [ -d "$ITEM" ] || continue
    ITEM="${ITEM%/}"
    [[ ":$PATH:" == *":$ITEM:"* ]] && continue
    ADD+="$ITEM:"
  done
  if [ -n "$ADD" ]; then
    PATH="$ADD$PATH"
    export PATH
  fi

  source_available_rc_files "$GHCIU_DIR"/cfg || return $?
  [ . -ef "$GHCIU_DIR" ] || source_available_rc_files cfg || return $?
}


function in_func () {
  case "$1" in
    eval ) eval "shift 2; $2";;
    * ) "$@";;
  esac || return $?$(echo W: "$FUNCNAME $* failed (rv=$?)" >&2)
}


function source_these_files () {
  local ARGS="$1"; shift
  local ITEM=
  for ITEM in "$@"; do
    [ -f "$ITEM" ] || [[ "$ITEM" != *'*'* ]] || continue
    in_func source -- "$ITEM" $ARGS || return $?
  done
}


function source_available_rc_files () {
  local RC= # NB: Do not re-declare CFG!
  for RC in "$@"; do
    for RC in "$RC".{local,@"$HOSTNAME"}; do
      source_these_files --config "$RC"{.,/}*.rc || return $?
    done
  done
}

















return 0
