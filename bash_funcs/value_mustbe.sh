#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function value_mustbe_simple_integer () {
  local DESCR="$1"; shift
  local VAL="$1"; shift
  local E="$DESCR must be a simple integer number"
  local NUM=
  if [ "$VAL" != 0 ]; then
    NUM="${VAL#-}"
    [ "${NUM:0:1}" != 0 ] || return 1$(echo "$E but has a leading zero!" >&2)
    [ -n "${NUM//[^0-9]/}" ] || return 1$(echo "$E but contains no digits!" >&2)
    [ -z "${NUM//[0-9]/}" ] || return 1$(echo "$E but contains non-digits!" >&2)
    let NUM="$VAL"
    [ "$VAL" == "$NUM" ] || return 1$(
      echo "$E but is not numerically equal to itself!" \
        "Does it exceed the shell's number range?" >&2)
  fi
  while [ "$#" -ge 1 ]; do
    VAL="$1"; shift
    case "$VAL" in
      [gl][te]:* )
        test "$NUM" -"${VAL%%:*}" "${VAL#*:}" && continue
        case "${VAL:0:1}" in
          g ) E+=' greater';;
          l ) E+=' lesser';;
        esac
        case "${VAL:1:1}" in
          t ) E="${E% *} strictly ${E##* } than";;
          e ) E+=' than or equal to';;
        esac
        echo "$E ${VAL#*:}!" >&2
        return 1;;
      * ) echo E: $FUNCNAME: "Unsupported criterion '$1'" >&2; return 4;;
    esac
  done
}






[ "$1" == --lib ] && return 0; value_mustbe_"$@"; exit $?
