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




return 0
