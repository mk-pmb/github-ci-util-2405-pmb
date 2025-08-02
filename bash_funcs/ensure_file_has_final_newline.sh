#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function ensure_file_has_final_newline () {
  while [ "$#" -ge 1 ]; do
    [ -f "$1" ] || return 4$(
      echo E: $FUNCNAME: "Expected a regular file: $1" >&2)
    tail --bytes=1 -- "$1" | tr '\r\n' '\n\r' | grep -qPe '\r$' \
      || echo >>"$1" || return 4$(
        echo E: $FUNCNAME: "Failed to add newline to: $1" >&2)
    shift
  done
}



[ "$1" == --lib ] && return 0; ensure_file_has_final_newline "$@"; exit $?
