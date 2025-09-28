#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function ghciu_repo_unpacker () {
  local -A UNP=(
    [dest]='#'
    [src]='ghtar:#'
    [branch]='master'
    [packs]=
    )
  local KEY= VAL=
  for KEY in "${!UNP[@]}"; do
    eval "VAL=\"\$UNPACKER_${KEY^^}\""
    [ -z "$VAL" ] || UNP["$KEY"]="$VAL"
  done

  local PACKS=()
  readarray -t PACKS < <(grep -oPe '\S+' <<<"${UNP[packs]}")
  unset UNP[packs]
  [ "${#PACKS[@]}" == 0 ] || set -- "$@" "${PACKS[@]}"

  while [ "$#" -ge 1 ]; do
    VAL="$1"; shift
    if [[ "$VAL" =~ ^([a-z_]+)= ]]; then
      UNP["${BASH_REMATCH[1]}"]="${VAL#*=}"
      continue
    fi
    ghciu_repo_unpacker__one_pack "$VAL" || return $?
  done
}


function ghciu_repo_unpacker__one_pack () {
  local PACK_NAME="$1"
  echo P: "Install pack '$PACK_NAME':"

  local DEST_DIR="${UNP[dest]//#/$PACK_NAME}"
  mkdir --parents -- "$DEST_DIR" || return $?$(
    echo E: $FUNCNAME: 'Failed to create destination directory' \
      "'$DEST_DIR' for pack '$PACK_NAME'!" >&2)

  pushd -- "$DEST_DIR" >/dev/null || return $?
  ghciu_repo_unpacker__one_pkg_fallible
  local RV="$?"
  popd -- >/dev/null || return $?
  return "$RV"
}


function ghciu_repo_unpacker__one_pkg_fallible () {
  local SRC="${UNP[src]//#/$PACK_NAME}"
  local OWNER="$GITHUB_REPOSITORY_OWNER"
  case "$SRC" in
    '' )
      echo E: $FUNCNAME: "Empty download URL for pack '$PACK_NAME'!" >&2
      return 4;;

    ghtar:=/* | \
    github:=/* | \
    '' )
      [ -n "$OWNER" ] || return 4$(echo E: $FUNCNAME: "Empty OWNER!" >&2)
      SRC="${SRC/=/$OWNER}";;

  esac

  local GIT_RESET=
  case "$SRC" in
    ghtar:*@=* | \
    git:http*://*@=* | \
    github:*@=* | \
    '' ) GIT_RESET="${SRC##*@=}"; BRAN="${SRC%@=*}";;
  esac

  local BRAN="${UNP[branch]}"
  case "$SRC" in
    ghtar:*@* | \
    git:http*://*@=* | \
    github:*@* | \
    '' ) BRAN="${SRC##*@}"; SRC="${SRC%@*}";;
  esac

  case "$SRC" in
    github:* ) SRC="git:https://github.com/$SRC.git";;
  esac

  case "$SRC" in
    ghtar:* )
      ghciu_repo_unpacker__download_"${SRC%%:*}" || return $?;;

    git:http*:* )
      echo D: Clone:
      git clone --single-branch --no-tags --branch="$BRAN" \
        -- "${SRC#*:}" . || return $?
      ;;

    * ) echo E: $FUNCNAME: "Unsupported download URL: $SRC" >&2; return 4;;
  esac

  [ -z "$GIT_RESET" ] || vdo git reset --hard "$GIT_RESET" || return $?
  ghciu_repo_unpacker__maybe_npm_install || return $?
}


function ghciu_repo_unpacker__download_ghtar () {
  local TGZ="$BRAN.tar.gz"
  local URL="https://github.com/${SRC#*:}/archive/refs/heads/$TGZ"
  mkdir --parents -- .git || return $?
  echo P: "Download: from $URL"
  wget --quiet --output-document=".git/$TGZ" -- "$URL" || return $?
  echo P: Unpack:
  tar --extract --gzip --file ".git/$TGZ" --strip-components=1 || return $?
}


function ghciu_repo_unpacker__maybe_npm_install () {
  [ -f package.json ] || return 0
  which npm | grep -qPe '^/' || return 0
  echo D: 'Install (npm):'
  npm install --ignore-scripts=true . || return $?
}














[ "$1" == --lib ] && return 0; ghciu_clone_npm_module "$@"; exit $?
