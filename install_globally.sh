#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function install_globally () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFPATH="$(readlink -m -- "$BASH_SOURCE"/..)"
  # cd -- "$SELFPATH" || return $?
  local ORIG= LINK= DEST_BASE='/usr/local/bin/ghciu'
  [ -L "$DEST_BASE" ] && rm -v -- "$DEST_BASE"
  ln -vsT -- "$SELFPATH"/u.sh "$DEST_BASE" || return $?
  for ORIG in "$SELFPATH"/bash_funcs/*.sh; do
    [ -x "$ORIG" ] || continue
    LINK="$DEST_BASE-$(basename -- "${ORIG//_/-}" .sh)"
    [ -L "$LINK" ] && rm -v -- "$LINK"
    ln -vsT -- "$ORIG" "$LINK" || return $?
  done
}

install_globally "$@"; exit $?
