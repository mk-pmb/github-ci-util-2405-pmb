#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function unindent () {
  local TX="$1"
  TX="${TX#$'\n'}"
  local IND="${TX%%[^ ]*}"
  TX="${TX#$IND}"
  TX="${TX//$'\n'$IND/$'\n'}"
  TX="${TX%$'\n'}"
  echo "$TX"
}


function unindent_vars_inplace () {
  while [ "$#" -ge 1 ]; do
    case "$1" in
      '' ) continue;;
      *=* ) eval "${1%%=*}"'="$(unindent "${1#*=}")"';;
      * ) eval "$1"'="$(unindent "$'"$1"'")"';;
    esac
    shift
  done
}


[ "$1" == --lib ] && return 0; unindent "$@"; exit $?
