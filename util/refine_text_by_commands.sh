#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function refine_text_by_commands () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  [ -n "$REFINE_ENCODE" ] || local REFINE_ENCODE='base64 -w 9009009009'
  [ -n "$REFINE_DECODE" ] || local REFINE_DECODE='base64 -d'
  local HELD="$( $REFINE_ENCODE )"
  local ARG= KEY= VAL= OPT= BUF=
  local RUN=()
  local EMPTY='warn'
  local SKIP_UNEXEC_FILES=
  while [ "$#" -ge 1 ]; do
    ARG="$1"; shift
    BUF=
    RUN=()
    case "$ARG" in
      '' ) continue;;
      --eval ) RUN=( eval "$1" ); shift;;
      --opportunistic ) SKIP_UNEXEC_FILES=+; continue;;

      --sed | \
      '' )
        RUN=( "${ARG#--}" )
        if [ "${1:0:1}" == - ]; then RUN+=( "$1" ); shift; fi
        RUN+=( "$1" ); shift;;

      --sed=* | \
      '' )
        ARG="${ARG#--}"
        RUN=( "${ARG%%=*}" )
        ARG="${ARG#*=}"
        if [ "${ARG:0:1}" == - ]; then
          RUN+=( "${ARG%%[$' \n']*}" )
          ARG="${ARG#*[$' \n']}"
        fi
        RUN+=( "$ARG" );;

      --empty=accept | \
      --empty=done | \
      --empty=fail | \
      --empty=undo | \
      --empty=warn | \
      '' ) EMPTY="${ARG#*=}"; continue;;

      -* ) echo E: $FUNCNAME: "Unsupported option: $ARG" >&2; return 4;;
      * )
        if [ ! -x "$ARG" ]; then
          [ -z "$SKIP_UNEXEC_FILES" ] || continue
          echo E: $FUNCNAME: "File is not executable: $ARG" >&2
          return 6$
        fi
        RUN=( "$ARG" );;
    esac
    if [ -n "${RUN[0]}" ]; then
      # We use echo instead of <<< to avoid writing a temporary file.
      BUF="$( echo "$HELD" | $REFINE_DECODE | "${RUN[@]}" | $REFINE_ENCODE )"
      # local -p
      if [ -n "$BUF" ]; then
        HELD="$BUF"
        BUF=
        continue
      elif [ "$EMPTY" == accept ]; then
        HELD=
        continue
      elif [ "$EMPTY" == done ]; then
        return 0
      elif [ "$EMPTY" == fail ]; then
        echo E: $FUNCNAME: "Got empty result from: $ARG" >&2
        return 2
      elif [ "$EMPTY" == undo ]; then
        continue
      elif [ "$EMPTY" == warn ]; then
        echo W: $FUNCNAME: "Refusing empty result from: ${RUN[*]}" >&2
        continue
      fi
      echo E: $FUNCNAME: "Control flow failure after running: $ARG" >&2
      return 4
    fi
    echo E: $FUNCNAME: "Control flow failure: Not implemented: $ARG" >&2
    return 4
  done
  # We use echo instead of <<< to avoid writing a temporary file.
  [ -z "$HELD" ] || echo "$HELD" | $REFINE_DECODE
}










refine_text_by_commands "$@"; exit $?
