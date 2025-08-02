#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function clo_cli_main () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local CLO_PATH="$(readlink -m -- "$BASH_SOURCE"/..)"
  cd -- "$CLO_PATH" || return $?

  tame_nodejs_error_messages |
  clo_file_paths
}


function preg_quote () { sed -re 's~[^A-Za-z0-9_ ]~\\&~g'; }


function clo_file_paths () {
  local SED= KEY= VAL=
  KEY='
    cwd=PWD
    workspace=GITHUB_WORKSPACE
    RUNNER_WORKSPACE
    HOME
    '
  for KEY in $KEY; do
    eval 'VAL="$'"${KEY##*=}"'"'
    VAL="$(echo "$VAL" | preg_quote)"
    [ -n "$VAL" ] || continue
    KEY="${KEY%=*}"
    KEY="${KEY,,}"
    SED+='s!(^|[^A-Za-z0-9_])'"$VAL"'!\1❴'"$KEY"'❵!g'$'\n'
  done
  sed -rf <(echo "$SED")
}


function tame_nodejs_error_messages () {
  sed -rf <(echo '
    s~(^|[^A-Za-z0-9_])(/mnt/|/home/)\S+?(/node_modules\b)~/…\3~g

    /^ +\[Symbol\((original|mutated)CallSite\)\]: \[/{
      : read_callsite_block
        /\],?$/!N
        s~\n *~ ~g
      t read_callsite_block
      d
    }
    ')
}










clo_cli_main "$@"; exit $?
