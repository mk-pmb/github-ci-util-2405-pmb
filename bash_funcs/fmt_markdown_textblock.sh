#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function fmt_markdown_textblock () {
  [ "$#" -ge 1 ] || set -- core
  "$FUNCNAME"__"$@"
  return $?
}


function fmt_markdown_textblock__core () {
  echo
  local VAL=
  case "$FMT" in
    inline ) ;;
    h[1-6] ) # initial headline
      FMT+='######'
      echo -n "${FMT:2:${FMT:1:1}} "
      FMT='inline';;
    '' ) echo '```text';;
    * )
      VAL="$(fmt_markdown_textblock__guess_syntaxlang_from_filename ."$FMT")"
      echo '```'"${VAL:-$FMT}";;
  esac

  local SED_OPTIM='
    # Strip terminal color codes:
    s~\x1b\[[0-9;]*m~~g
    s~\x1b\[K~~g
    s~\r~~g
    '

  # How can we escape "`" and "<" characters at the start of a line for
  # GitHub-flavored markdown?
  # I tried a preceeding backslash, it will be printed verbatim.
  # SED_OPTIM+=$'\n''s~^\x60~\&#96;~g;s~^<~\&lt;~g'
  # I tried HTML entities, they will be printed verbatim.
  # SED_OPTIM+=$'\n''s~^\x60|^<~\\&~g'
  # I tried a zero-width non-joiner, … it's invisible at least.
  SED_OPTIM+=$'\n''s~^(\s*)(\x60|<)~\1\xE2\x80\x8C\2~'

  LANG=C sed -re "$SED_OPTIM"

  [ "$FMT" == inline ] || echo '```'
  # echo; echo "trace:$(printf -- ' &larr; `%s`' "${FUNCNAME[@]}")"
  echo
}


function fmt_markdown_textblock__deco () {
  # e.g. FMT=h2 fmt_markdown_textblock stepsumm deco --volcano 'Build failed!'
  [ -n "$FMT" ] || local FMT=inline
  local DECO="$1"; shift
  case "$DECO" in
    --volcano ) DECO='&#x1F525;&#x1F30B;&#x1F525;';;
  esac
  local MSG="$DECO $* $DECO"
  <<<"$MSG" fmt_markdown_textblock__core
}


function fmt_markdown_textblock__capture_command () {
  "$@" &> >(fmt_markdown_textblock__core); return $?
}


function fmt_markdown_textblock__stepsumm () {
  # <<<"$MSG" fmt_markdown_textblock stepsumm
  [ -n "$GITHUB_STEP_SUMMARY" ] || return 0
  fmt_markdown_textblock "$@" >>"$GITHUB_STEP_SUMMARY" || return $?
  ghciu_ensure_stepsumm_size_limit || return $?
}


function ghciu_stepsumm_dump_textblock () {
  # Deprecated. Use "fmt_markdown_textblock stepsumm …" instead.
  fmt_markdown_textblock stepsumm "$@"; return $?
}


function ghciu_stepsumm_dump_file () {
  fmt_markdown_textblock stepsumm details_file "$@"; return $?
}


function fmt_markdown_textblock__details () {
  echo
  case "$1" in
    '<open>'* ) echo "<details open><summary>${1#*>}</summary>";;
    * ) echo "<details><summary>$1</summary>";;
  esac
  shift
  fmt_markdown_textblock "$@"
  local RV=$?
  echo "</details>"
  echo
  return "$RV"
}


function fmt_markdown_textblock__details_file () {
  local FILE="$1"; shift
  case "$FILE" in
    *' '* )
      echo W: $FUNCNAME: "Filename contains unusual characters." \
        "If you meant to use options (e.g. --title)," \
        "they have to go _after_ the filename!" >&2;;
  esac
  [ "${FILE:0:1}" != - ] || return 4$(echo E: $FUNCNAME: >&2 \
    "File name must not start with '-' (consider './-…'): $FILE")
  [ -f "$FILE" ] || return 4$(echo E: $FUNCNAME: >&2 \
    "File must be a regular file: $FILE")
  local ARG=
  local TITLE="$FILE"
  local FMT="$FMT"
  if [ -z "$FMT" ]; then
    FMT="${FILE##*.}"
    FMT="${FMT,,}"
    case "$FMT" in
      *[^a-z0-9]* ) FMT=;;
    esac
  fi
  [ -n "$FMT" ] || FMT='text'
  while [ "$#" -ge 1 ]; do
    ARG="$1"
    [ "${ARG:0:1}" == - ] || break
    shift
    case "$ARG" in
      -- ) break;;
      --title ) TITLE="$1"; shift;;
      --basename ) TITLE="$(basename -- "$TITLE")";;
      --open ) TITLE="<open>${TITLE#<open>}";;
      --count-lines | \
      -- ) "$FUNCNAME${ARG//-/_}" "$@" || return $?;;
      * ) echo E: $FUNCNAME: "Unsupported option: $ARG" >&2; return 4;;
    esac
  done
  fmt_markdown_textblock__details "$TITLE" "$@" <"$FILE" || return $?
}


function fmt_markdown_textblock__details_file__count_lines () {
  sleep 1s # Wait for GitHub's file system cache to settle
  local N_LN="$(wc --lines -- "$FILE" | grep -oPe '^\d+')"
  local SIZE="$(du --apparent-size --human-readable -- "$FILE")"
  SIZE="${SIZE%%$'\t'*}"
  # SIZE="${SIZE// /}"
  TITLE+=" ($SIZE bytes, $N_LN lines)"
}


function fmt_markdown_textblock__dump_ghoutput () {
  fmt_markdown_textblock__details_file "$GITHUB_OUTPUT" \
    --title 'GitHub step output variables' \
    "$@"
}


function ghciu_ensure_stepsumm_size_limit () {
  [ -n "$GITHUB_STEP_SUMMARY" ] || return 0
  local SZ="$(stat -c %s -- "$GITHUB_STEP_SUMMARY")"
  local MAX=1024000
  [ "${SZ:-0}" -gt "$MAX" ] || return 0
  local TMPF="tmp.$$.github_step_summary_too_long.txt"
  echo '⚠ W: `$GITHUB_STEP_SUMMARY` is critically large ('"$(
    du --human-readable -- "$GITHUB_STEP_SUMMARY" | grep -oPe '^\S+'
    ), approaching GitHub's upload limit. &rArr; Cutting it at" \
    "${MAX/%000/k}."$'\n\n' >"$TMPF" || return $?
  head --bytes="$MAX" -- "$GITHUB_STEP_SUMMARY" >>"$TMPF" || return $?
  mv --no-target-directory -- "$TMPF" "$GITHUB_STEP_SUMMARY" || return $?
}


function fmt_markdown_textblock__guess_syntaxlang_from_filename () {
  local SRC="$1" FEXT= FMT= VAL=
  SRC="$(basename -- "$SRC")"

  # All lowercase?
  VAL="${SRC,,}"
  [ -n "$FMT" ] || [ "$VAL" != "$SRC" ] || case "$VAL" in
    .git[a-z]* | \
    .*ignore | \
    . ) FMT='text';;
    *[a-z]* ) ;;
    * ) return 0;; # no letters in filename => unknown type.
  esac

  FEXT="${SRC##*.}"
  [ -n "$FMT" ] || case "$FEXT" in
    '' ) ;;

    bat )     FMT='batch';;
    c )       FMT='c';;
    ceson )   FMT='js';;
    cfg )     FMT='ini';;
    cjs )     FMT='js';;
    cmd )     FMT='batch';;
    conf )    FMT='ini';;
    cpp )     FMT='cpp';;
    cs )      FMT='csharp';;
    csproj )  FMT='xml';;
    eml )     FMT='text';;
    htm )     FMT='html';;
    inf )     FMT='ini';;
    jsonl )   FMT='js';;
    log )     FMT='text';;
    md )      FMT='text';;
    md5 )     FMT='text';;
    mjs )     FMT='js';;
    patch )   FMT='diff';;
    pl )      FMT='perl';;
    ps1 )     FMT='pwsh';;
    psd1 )    FMT='pwsh';;
    psm1 )    FMT='pwsh';;
    rc )      FMT='bash';;
    reg )     FMT='ini';;
    sh )      FMT='bash';;
    sha )     FMT='text';;
    txt )     FMT='text';;
    yml )     FMT='yaml';;

    diff | \
    html | \
    ini | \
    js | \
    json | \
    py | \
    sed | \
    sql | \
    tex | \
    toml | \
    xml | \
    yaml | \
    '' ) FMT="$FEXT";;
  esac

  # First segment all uppercase? (e.g. LICENSE, COPYING, AUTHORS, CREDITS)
  VAL="${SRC%%.*}"
  [ -n "$FMT" ] || [ "$VAL" != "${VAL^^}" ] || case "$VAL" in
    [A-Z][A-Z][A-Z][A-Z]* ) FMT='text';;
  esac

  [ -z "$FMT" ] || echo "$FMT"
}


function fmt_markdown_textblock__bundle_files () {
  local -A HOW=(
    [max_dump_files]=256
    [max_dump_size]=$(( 4 * 1024 * 1024 ))
    )
  local KEY= VAL= FMT=
  while [ "$#" -ge 1 ]; do
    case "$1" in
      -- ) shift; break;;
      --*=* ) VAL="${1#--}"; HOW["${VAL%%=*}"]="${VAL#*=}"; shift;;
      * ) break;;
    esac
  done

  [ "$#" -ge 1 ] || return 4$(echo E: $FUNCNAME: 'No input files given.' >&2)
  [ "$#" -le "${HOW[max_dump_files]}" ] || return 4$(echo E: $FUNCNAME: >&2 \
    "Too many input files ($# > ${HOW[max_dump_files]})")
  printf -v VAL -- '</%s>\n' "$@"

  local APOS="'" GRAV='`' QUOT='"'
  # Construct our todo list:
  exec < <(
    # Priority files
    echo "$VAL" | grep -Fe '</package.json>'
    echo "$VAL" | grep -Fe '/package.json>'
    echo "$VAL" | grep -Fe '</README'
    echo "$VAL" | grep -Fe '/README'

    # All other files
    echo "$VAL"
    )

  local -A HAD=() SKIPPED=()
  local SRC= FMT= SIZE= OTHER=
  local FMT_STATS=
  while IFS= read -r SRC; do
    SRC="${SRC#'</'}"
    SRC="${SRC#/}"
    SRC="${SRC%'>'}"
    [ -n "$SRC" ] || continue
    [ -f "$SRC" ] || continue
    [ -z "${HAD["$SRC"]}" ] || continue
    HAD["$SRC"]=+
    if [ -L "$SRC" ]; then
      OTHER+="* $GRAV$SRC$GRAV: symlink to $GRAV$(
        readlink -- "$SRC")$GRAV"$'\n'
      FMT_STATS+=$'symlink\n'
      continue
    fi
    if [ ! -s "$SRC" ]; then
      OTHER+="* $GRAV$SRC$GRAV: empty"$'\n'
      continue
    fi

    SIZE="$(stat -c %s -- "$SRC")"
    # Expecting at least 1 byte because we already checked -s above.
    [ "${SIZE:-0}" -ge 1 ] || return 4$(echo E: $FUNCNAME: >&2 \
      "Cannot determine file size of non-empty input file: $SRC")
    [ "$SIZE" -gt "${HOW[max_dump_size]}" ] || FMT="$(
      fmt_markdown_textblock__guess_syntaxlang_from_filename "$SRC")"
    if [ -z "$FMT" ]; then
      OTHER+="* $GRAV$SRC$GRAV: $SIZE bytes, $(file --brief -- "$SRC")"$'\n'
      FMT_STATS+=$'other\n'
      continue
    fi
    FMT_STATS+="$FMT"$'\n'
    VAL="File $GRAV$SRC$GRAV:"
    VAL="$(FMT="$FMT" ghciu --no-log --succeed-quietly \
      fmt_markdown_textblock details_file "$SRC" --title "$VAL")"
      # ^-- ghciu = github-ci-util-2405-pmb
    echo "$VAL<!-- end of $FMT file $QUOT$SRC$QUOT -->"
    echo
  done

  if [ -n "$OTHER" ]; then
    echo '<details><summary>Other files:</summary>'
    echo
    echo "$OTHER"
    echo '</details>'
    echo
  fi

  FMT_STATS="$(echo -n "$FMT_STATS" | sort --version-sort | uniq --count |
    sort --general-numeric-sort --reverse |
    sed -re 's~^\s+([0-9]+)\s(.*)$~\2×\1~')"
  FMT_STATS="${FMT_STATS//$'\n'/, }"
  echo "File type stats: $FMT_STATS"
}














[ "$1" == --lib ] && return 0; fmt_markdown_textblock "$@"; exit $?
