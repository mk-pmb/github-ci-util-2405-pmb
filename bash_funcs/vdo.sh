#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function vdo () {
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
  echo "# >>--->> $VDO_DESCR" \
    ">>------------------------------------------>>"
  "$@"
  local VDO_RV=$?
  echo "# <<---<< $VDO_DESCR, rv=$VDO_RV" \
    "<<------------------------------------------<<"
  echo
  return $VDO_RV
}


[ "$1" == --lib ] && return 0; vdo "$@"; exit $?
