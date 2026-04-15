#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-
set -e
SELF="$(readlink -f -- "$BASH_SOURCE")" # busybox
cd -- "${SELF%/*}"
DEST_BASE='ghciu'
( sed -nre '2p;2q' -- "$SELF"
  echo "$DEST_BASE <- cli.sh"
  for ORIG in bash_funcs/*.sh; do
    [ -x "$ORIG" ] || continue
    LINK="$DEST_BASE-$(basename -- "${ORIG//_/-}" .sh)"
    echo "$LINK <- $ORIG" || return $?
  done
) >binlinks.cfg
