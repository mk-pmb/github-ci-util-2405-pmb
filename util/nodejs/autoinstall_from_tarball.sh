#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function ain_cli_init () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local DBGLV="${DEBUGLEVEL:-0}"
  local GHCIU_DIR="$(readlink -f -- "$BASH_SOURCE"/../..)"
  local CI_INVOKED_IN="$PWD"
  local CI_FUNCD="$GHCIU_DIR/bash_funcs"
  case "$1" in
    --func ) shift; "$@"; return $?;;
    --prescan ) shift; ain_prescan_tarball_files_list "$@"; return $?;;
  esac
  ain_fallible "$@" || return $?$(
    echo E: "Node.js autoinstaller failed, rv=$?" >&2)
}


function ain_fallible () {
  echo -n "D: Checking arg 1 = DEST_BASE = '$1': "
  ain_checkarg_dirpath "$1" || return $?
  local DEST_BASE="$1"; shift

  echo -n "D: Checking arg 2 = TARBALLS_DIR = '$1': "
  ain_checkarg_dirpath "$1" || return $?
  local TARBALLS_DIR="$1"; shift

  echo -n "D: Checking arg 3 = NODEJS_VER = '$1': "
  local NODEJS_VER="$1"; shift
  local ALLOW_LATER_VERSION=
  local TARBALL_BFN=
  NODEJS_VER="${NODEJS_VER%.0}"
  NODEJS_VER="${NODEJS_VER%.0}"
  case "$NODEJS_VER" in
    --exact-tarball=* ) TARBALL_BFN="${NODEJS_VER#*=}"; NODEJS_VER=;;
    '^'[1-9][0-9] ) ;;
    '~'[1-9][0-9] ) ;;
    [1-9][0-9] ) ;;
    [1-9][0-9].x ) ;;
    '>='[1-9][0-9] ) ALLOW_LATER_VERSION=+;;
    * )
      echo E: 'Unsupported notation.' \
        "Try '^' or '>=' followed by exactly two digits." >&2
      return 4;;
  esac
  NODEJS_VER="${NODEJS_VER//[^0-9]/}"
  echo ok.

  local UNINSTALL=
  case "$1" in
    --recklessly-reinstall | \
    --recklessly-uninstall )
      UNINSTALL="${1#*y-}"
      UNINSTALL="${UNINSTALL%in*}"
      shift;;
  esac

  local UNPACK_TMPPFX="${1:-tmp.unpack.}"; shift

  [ "$#" == 0 ] || return 4$(
    echo -n E: "unexpected additional CLI arguments (n=$#):" >&2
    printf -- ' ‹%s›' "$@" >&2; echo >&2)

  [ -n "$TARBALL_BFN" ] || ain_obtain_tarball || return $?
  local TARBALL_ABS="$TARBALLS_DIR$TARBALL_BFN"
  echo D: "Using local tarball: $TARBALL_ABS"
  ain_unpack_tarball "$TARBALL_ABS" || return $?
}


function ain_checkarg_dirpath () {
  [[ "$1" == */ ]] || return 4$(echo E: "must end with a slash!" >&2)
  case "$1" in
    [A-Za-z]* ) ;;
    /* | ./* | ../* ) ;;
    * )
      echo E: "must start with '/', './', '../' or a letter!" >&2
      return 4;;
  esac
  [ -d "$1" ] || return 4$(echo E: "must be an existing directory!" >&2)
  echo ok.
}


function ain_prescan_tarball_files_list () {
  case "$1" in
    '' ) ;;
    *.tar.[a-z][a-z] | \
    *.tar ) ain_autodecompress_file "$1" | tar t | "$FUNCNAME"; return $?;;
    *.lst | \
    *.txt ) cat "$1" | "$FUNCNAME"; return $?;;
  esac
  local RGX='^/?node-v[\w\.\-]+/(
    bin|
    include|
    lib/\w+|
    share/doc|
    $)/[\w\.\-]+(?=/|$)
    '
  RGX="${RGX//$'\n'/}"
  RGX="${RGX// /}"
  # The uniq before sort is to ease the burden on sort's RAM buffer,
  # because uniq can discard most of the input with a much smaller buffer.
  grep -oPe "$RGX" | uniq | sort -Vu
}


function ain_obtain_tarball () {
  local PLATF="$(uname -m)"
  # ^-- NB: uname -p is deprecated on some systems. Also it would produce
  #     the wrong result, e.g. "powerpc" on IBM POWER systems whereas the
  #     suitable node.js tarball name would have "ppc64le".
  # Nonetheless, even with -m, we have to amend some special snowflakes:
  case "$PLATF" in
    x86_64 ) PLATF='x64';;
  esac

  local VAL= BFN= VER=
  VAL="$(cd -- "$TARBALLS_DIR" &&
    printf -- '%s\n' node-v[0-9]*-linux-"$PLATF".tar.[gx]z |
    grep -xPe '[\w\-\.]+' | sort -rV)" # -rV = latest version first
  for BFN in $VAL ''; do
    [ -f "$TARBALLS_DIR$BFN" ] || continue
    VER="${BFN##*node-v}"
    VER="${VER%%-linux-*}"
    VER="${VER%%.*}"
    [ -z "${VER//[0-9]/}" ] || continue$(
      echo W: "Skip tarball with non-digit in major version: '$BFN'" >&2)
    [ "$DBGLV" -lt 4 ] || echo D: 'checking tarball:' \
      "$VER = $NODEJS_VER$ALLOW_LATER_VERSION? $BFN" >&2
    [ "$VER" == "$NODEJS_VER" ] && break
    [ -n "$ALLOW_LATER_VERSION" -a "$VER" -ge "$NODEJS_VER" ] && break
  done
  if [ -n "$BFN" ]; then
    echo D: "Found matching local tarball: $BFN"
    TARBALL_BFN="$BFN"
    return 0
  fi
  VAL=

  local DL_PROG='wget'
  local DL_QUIET='--quiet'
  local DL_CONTINUE='--continue'
  local DL_SAVE_AS='--output-document='
  if ! wget --version | grep -qPe '(^| )\+https( |$)'; then
    echo W: "Installed version of wget doesn't support HTTPS!" \
      '=> Using curl instead.' >&2
    DL_PROG='curl'
    DL_PROG+=' --location' # follow redirects
    DL_QUIET='--silent'
    DL_CONTINUE+='-at -'
    DL_SAVE_AS='--output ' # the final space is intentional
  fi


  echo D: 'Found no matching local tarball. => Trying to find a download.'
  local DL_BASE='https://nodejs.org/dist/'
  local URL="${DL_BASE}index.json"
  local VERLIST_CACHE="${TARBALLS_DIR}node-versions-list.$(
    printf -- '%(%d%m%y)T' -1).json"
  local TMPF="${VERLIST_CACHE%.*}.$$.part"
  if [ -s "$VERLIST_CACHE" ]; then
    echo D: "Use existing versions list: $VERLIST_CACHE"
  else
    echo D: "Download versions list: $VERLIST_CACHE <- $URL"
    $DL_PROG $DL_QUIET $DL_SAVE_AS"$TMPF" -- "$URL" || return $?
    mv -vT -- "$TMPF" "$VERLIST_CACHE" || return $?
  fi

  VER='"version":\s*"v[\d\-\.]+(?=")'
  if [ -n "$ALLOW_LATER_VERSION" ]; then
    # Just use the latest LTS
    VAL='"lts":("|true)'
    VER="$(grep -Fe "$VAL" -- "$VERLIST_CACHE" | grep -oPe "$VER")"
  else
    VAL='"v'"$NODEJS_VER."
    VER="$(grep -oPe "$VER" -- "$VERLIST_CACHE" | grep -Fe "$VAL")"
  fi
  # Pick the latest acceptable version:
  VER="$(echo "$VER" | cut -d v -sf 3 | sort -rV | head -n 1)"
  BFN="node-v$VER-linux-$PLATF.tar.xz"
  TARBALL_BFN="$BFN"
  URL="${DL_BASE}v$VER/$BFN"
  VAL="$TARBALLS_DIR$BFN"
  echo D: "Download v$VER from: $URL"
  TMPF="$VAL.part"
  $DL_PROG $DL_CONTINUE $DL_SAVE_AS"$TMPF" -- "$URL" || return $?
  mv -vT -- "$TMPF" "$VAL" || return $?
}


function ain_autodecompress_file () {
  local SRC_FN="$1"; shift
  local PIPE=
  case "$SRC_FN" in
    *.xz ) PIPE='| unxz';;
    *.gz ) PIPE='| gzip -d';;
  esac
  eval 'pv -- "$SRC_FN"'"$PIPE"
}


function ain_unpack_tarball () {
  local TARBALL_ABS="$1"; shift
  echo D: "Detecting wrapper directory name in tarball: $TARBALL_ABS"
  local EXTRACT_THESE_FILES="$(ain_prescan_tarball_files_list "$TARBALL_ABS")"
  local TAR_PFX="${EXTRACT_THESE_FILES#/}"
  TAR_PFX="${TAR_PFX%%/*}"
  case "$TAR_PFX" in
    *$'\n'* ) echo E: "A string operation failed for TAR_PFX."; return 4;;
    node-v* ) ;;
    * ) echo E: "Failed to detect the wrapper directory name."; return 4;;
  esac

  local VER_DIR="$TAR_PFX"
  VER_DIR="${VER_DIR#node-}"
  VER_DIR="${VER_DIR%-linux-*}"
  VER_DIR="$UNPACK_TMPPFX$EPOCHSECONDS.$$.$RANDOM"

  local VAL= AUX= PAR=
  VAL="$VER_DIR"
  [ "${VAL:0:1}" == / ] || VAL="$PWD/$VAL"
  for VAL in "$VAL" $EXTRACT_THESE_FILES; do
    [ "${VAL:0:1}" == / ] || VAL="$DEST_BASE$VAL"
    [ -d "$VAL" ] || continue
    AUX=+
    echo E: "Directory already exists, please rename or delete: '$VAL'" >&2
  done
  [ -z "$AUX" ] || return 4$(
    echo E: 'Cannot unpack: Some destination directories already exist.' >&2)

  case "$UNINSTALL" in
    un | re ) ain_recklessly_uninstall || return $?;;&
    re ) ;;
    un ) return 0;;
  esac

  echo D: "Extract $TARBALL_ABS -> $VER_DIR/."
  mkdir -- "$VER_DIR" || return $?
  ain_autodecompress_file "$TARBALL_ABS" | tar x -C "$VER_DIR"

  echo -n D: "Move files from $VER_DIR/ -> $DEST_BASE: "
  local VER_PFX="$VER_DIR/$TAR_PFX"
  for VAL in $EXTRACT_THESE_FILES; do
    VAL="${VAL#*/}"
    PAR="$DEST_BASE$(dirname -- "$VAL")"
    mkdir -p -- "$PAR"
    mv -t "$PAR"/ -- "$VER_PFX/$VAL" || return $?
    rmdir --ignore-fail-on-non-empty -p -- "$VER_PFX/$(dirname -- "$VAL")"
  done

  local DEST_BIN="$DEST_BASE"bin
  ln -sfT node "$DEST_BIN"/nodejs || return $?

  VAL='share/doc/node'
  echo -n "$VAL… "
  VAL="$DEST_BASE$VAL"
  mv -t "$VAL" -- "$VER_PFX"/LICENSE || return $?
  mv -t "$VAL" -- "$VER_PFX"/*.md || return $?

  VAL="share/man"
  echo -n "$VAL… "
  VAL="$VER_PFX/$VAL"
  rm -- "$VAL"/man*/node.* || return $?
  rmdir -- "$VAL"/man* || return $?
  rmdir -- "$VAL" || return $?
  rmdir -- "$VER_PFX/share" || return $?
  rmdir -- "$VER_PFX" || return $?
  rmdir -- "$VER_DIR"
  # ^-- We can't use `rmdir -p` because $UNPACK_TMPPFX may include a prefix
  #     not meant to be deleted.

  if [ -d "$VER_DIR" ]; then
    ls -Al -- "$VER_DIR"
    echo E: "There seem to be unexpected leftover files in: $VER_DIR" >&2
    return 4
  fi

  echo 'done!'
  echo -n "D: Versions in your current shell: "
  ain_versions_check || echo ' (errors ignored)' >&2
  echo -n "D: Versions in destination prefix: "
  PATH="$DEST_BIN:$PATH" ain_versions_check || return $?
}


function ain_versions_check () {
  local PROG= VAL= ACCUM= FAILS=
  local RGX='^v?¹\.¹\.¹$'
  RGX="${RGX//¹/[0-9]+}"
  for PROG in nodejs npm ; do
    VAL="$($PROG --version || echo fail: rv=$?)"
    if [[ "$VAL" =~ $VER_RGX ]]; then
      ACCUM+=", $PROG: ${VAL#v}"
    else
      FAILS+=", $PROG"
    fi
  done
  echo "${ACCUM#, }"
  [ -n "$FAILS" ] || return 0
  echo E: "Failed to detect the versions of:${FAILS#,}" >&2
  return 2
}


function ain_recklessly_uninstall () {
  local VAL=
  for VAL in $EXTRACT_THESE_FILES; do
    VAL="${VAL#$TAR_PFX/}"
    [ -n "$VAL" ] || continue
    VAL="${DEST_BASE%/}/$VAL"
    echo -n D: "uninstall: $VAL: "
    if [ ! -e "$VAL" ]; then
      echo 'not found. skip.'
      continue
    fi
    rm -r -- "$VAL"
    [ ! -e "$VAL" ] || return 4$(echo E: 'Failed to rm.' >&2)
    echo 'removed.'
  done
}












ain_cli_init "$@"; exit $?
