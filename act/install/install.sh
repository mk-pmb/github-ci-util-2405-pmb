#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function install_ghciu () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local REPOPATH="$(readlink -m -- "$BASH_SOURCE"/../../..)"
  "$REPOPATH"/install_globally.sh || return $?
  ghciu ghciu+s://act/install/gather_ci_run_meta.sh || return $?
}


install_ghciu "$@"; exit $?
