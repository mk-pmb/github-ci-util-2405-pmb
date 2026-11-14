#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function ci_audit_cli_init () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  trap 'echo T: "Failed at $BASH_SOURCE line $LINENO: $BASH_COMMAND" >&2' ERR
  set -o errexit -o pipefail
  local GHCIU_DIR="$(readlink -f -- "$BASH_SOURCE"/../../..)"
  local TXB="$GHCIU_DIR"/bash_funcs/fmt_markdown_textblock.sh

  ghciu -Q npm install --package-lock-only .
  ghciu -Q npm audit fix --package-lock=true --dry-run --force &> >(
    tee -- tmp.ghciu-npm-audit.log)
  exec < <( grep -Fie vulnerab -- tmp.ghciu-npm-audit.log | sort -Vu )

  local SED='
    1{
      s~^~«shield» «warn» npm audit log summary:\n~
      ${/\n[Ff]ound 0 vuln/s!«warn»!«good»!; s!\n! !}
    }
    8{s!^.*$!…!; q}
    '
  local VAL="$( head --bytes=2K | LANG=C sed -rf <(echo "$SED") )"
  local FMT='text'
  case "$VAL" in
    *$'\n'* ) ;;
    * ) FMT='inline';;
  esac
  VAL="${VAL//'«good»'/'✅️'}"
  VAL="${VAL//'«shield»'/'🛡️'}"
  VAL="${VAL//'«warn»'/'⚠️'}"
  echo "$VAL" | FMT="$FMT" "$TXB" stepsumm
}





ci_audit_cli_init "$@"; exit $?
