#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function lib_report__panic () {
  echo '!! 🔥🌋🔥 !! PANIC !! 🔥🌋🔥 !! 🔥🌋🔥 !! 🔥🌋🔥 !! 🔥🌋🔥 !! 🔥🌋🔥 !!'
  echo "!! $*"
  echo '!! 🔥🌋🔥 !! PANIC !! 🔥🌋🔥 !! 🔥🌋🔥 !! 🔥🌋🔥 !! 🔥🌋🔥 !! 🔥🌋🔥 !!'
  echo '!!'
  env | grep -Pie 'github|container|runtime' \
    | LANG=C sort | sed -re 's!^([^=]+)=!\1:\n\1=!'
  exit 8
}


function lib_report__link_badge () {
  local -A BADGE=()
  local VAL=
  for VAL in "$@"; do BADGE["${VAL%%=*}"]="${VAL#*=}"; done

  if [ -z "${BADGE[url]}" ]; then
    LINK_WRAP_TAG='del'
    # ^-- An attempt to make uncolored icon characters red.
    VAL="error:${BADGE[error_name]:-no_error_name_provided}"
    BADGE[url]="#$VAL"
    BADGE[icon]="${BADGE[error_icon]:-%disabled_car}"
    [ -z "${BADGE[error_title]}" ] || BADGE[title]="${BADGE[error_title]}"
    BADGE[icon]="${BADGE[error_icon]:-%disabled_car}"
  fi
  case "${BADGE[icon]}" in
    %disabled_car ) BADGE[icon]='&#x26CD;';;
    %emergency ) BADGE[icon]='&#x1F6A8;';;
    %scroll ) BADGE[icon]='&#x1F4DC;';;
    %shield ) BADGE[icon]='&#x1F6E1;&#xFE0F;';;
  esac

  local HTML='<img align="right"'$(
    # ^-- We have to abuse ancient img align because GitHub's
    #     HTML sanitization will eat any modern solution.
    )' src="about:blank" alt="'"${BADGE[icon]:-?!}"'"'
  [ -z "${BADGE[title]}" ] || HTML+=' title="'"${BADGE[title]}"'"'
  HTML+='>'
  case "${BADGE[url]}" in
    '' | : | - | + | '#' ) ;;
    * ) HTML='<a href="'"${BADGE[url]}"'">'"$HTML</a>";;
  esac
  [ -z "$LINK_WRAP_TAG" ] || HTML="<$LINK_WRAP_TAG>$HTML</$LINK_WRAP_TAG>"

  if [ -z "$GITHUB_STEP_SUMMARY" ]; then
    echo "$HTML"
    return $?
  fi

  echo "$HTML" >>"$GITHUB_STEP_SUMMARY"
  lib_report__merge_link_badges -i -- "$GITHUB_STEP_SUMMARY"
}


function lib_report__merge_link_badges () {
  local SED_MERGE_BADGES='
    s~[\f\r]~~g
    s~<img align="right" [^<>]*>~\f&\r~g
    s~(<a [^<>]*>)\f([^\f\r]+)\r(</a\s*>)~\f\1\2\3\r~g
    s~(<del>)\f([^\f\r]+)\r(</del\s*>)~\f\1\2\3\r~g
    s~\s*>\r[\n\t ]*\f~>~g
    # ^-- Newline inside a closing tag here would confuse GitHub. :-(
    s~[\n\t ]*[\f\r][\n\t ]*~\n~g
    s~\n{3,}~\n\n~g
    '
  LANG=C sed -zre "$SED_MERGE_BADGES" "$@"
}









case "$1" in
  --lib ) return 0;;
  --debug ) shift; lib_report__"$@"; exit $?;;
esac
echo E: "Don't run $0 directly!" 'For the thing that reports your errors,' \
  'you need early warning if it becomes unavailable (e.g. due to rename)!' >&2
return 8 || exit 8
