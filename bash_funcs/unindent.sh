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


[ "$1" == --lib ] && return 0; unindent "$@"; exit $?
