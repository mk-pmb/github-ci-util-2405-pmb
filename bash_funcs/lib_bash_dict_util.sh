#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function eq_keyval_assign () {
  local A="$1"; shift
  [[ "$A" =~ ^[A-Za-z0-9_]+\[\]$ ]] && A="${A%']'}"'"$K"]="$V"'
  local K= V=
  while [ "$#" -ge 1 ]; do
    V="$1"; shift
    K="${V%%=*}"
    [ "$V" != "$K" ] || V=
    V="${V#*=}"
    eval "$A"
  done
}


function json_to_bash_dict_init () {
  DATA="$1" CODE='clog(toBashDictSp(data))' enveval2401-pmb
}


function cfg_include_exclude_wordlists_prepare () {
  local D="$1"; shift
  local K= V=
  while [ "$#" -ge 1 ]; do
    K="$1"; shift
    case "$K" in
      *[A-Za-z0-9] ) ;;
      * ) # Append {in,ex}clude to keys that end in a special character:
        set -- "${K}include" "$@"; K+='exclude';;
    esac
    eval V='${'"$D"'[$K]}'
    V=" ${V//$'\n'/ } "
    [ "${V// /}" == '*' ] && V='*'
    eval "$D"'["$K"]="$V"'
  done
}


function cfg_include_exclude_wordlists_check () {
  local D="$1" K="$2" V="$3" L=
  [ -n "$V" ] || return 1 # invalid value
  # local -p
  eval L='${'"$D"'[${K}include]}'
  [ "$L" == '*' ] || [[ "$L" == *" $V "* ]] || return 1 # not included
  eval L='${'"$D"'[${K}exclude]}'
  [ -z "$L" ] || [[ "$L" != *" $V "* ]] || return 1 # excluded
  return 0 # accepted
}








return 0
