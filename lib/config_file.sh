#!/usr/bin/env bash
#
# config_file.sh
#
# Lightweight configuration helper library for modifying simple system
# configuration files that follow a key/value model.
#
# Supported formats:
#
#   KEY=value
#   KEY value
#
# The library operates on a line-by-line basis and is intended for files
# where configuration can be safely modified by locating a key and replacing
# or appending a single line.
#
# Transaction model
# -----------------
#
# All modifications are performed on a temporary working copy of the target
# configuration file. The original file is never modified directly.
#
# The typical workflow is:
#
#   1. Begin a configuration transaction
#   2. Copy the target file to a temporary working file
#   3. Apply all modifications to the temporary file
#   4. Commit the transaction by replacing the original file
#
# This approach provides:
#
#   - atomic updates to configuration files
#   - a basis for rollback support
#   - a basis for backup/version support
#   - protection against partially applied changes
#
# Scope
# -----
#
# This library intentionally supports only simple key/value configuration
# files. Files that require structural or syntax-aware parsing should be
# handled by dedicated modules instead.
#
# Not supported:
#
#   - nested or block-based configuration
#   - multi-line values
#   - structured formats (YAML, JSON, XML, etc.)
#   - configuration where ordering or context is semantically significant
#
# The goal of this library is to remain small, predictable, and safe for
# simple configuration edits.
#
#
# Duplicate-key policy
# --------------------
#
# This library treats multiple active entries for the same key as ambiguous.
# For single-key operations:
#
#   - commented historical entries are allowed
#   - at most one active entry is allowed
#   - if multiple active entries exist, the operation fails
#
# Function behaviour:
#
#   config_set_kv:
#       0 active   -> append new active entry
#       1 active   -> replace active entry
#       2+ active  -> fail
#
#   config_comment_kv:
#       0 active   -> fail
#       1 active   -> comment active entry
#       2+ active  -> fail
#
#   config_uncomment_kv:
#       active exists        -> fail
#       0 active, 1 comment  -> uncomment
#       0 active, 2+ comment -> fail
#
#   config_remove_active_kv:
#       0 active   -> fail
#       1 active   -> remove active entry
#       2+ active  -> fail
#

CONFIG_TXN_COUNTER=0

config_profile_get() {
    local profile="$1"
    local field="$2"
    local var_name="${profile}__${field}"

    printf '%s' "${!var_name:-}"
}

_config_txn_set() {
    local txn="$1"
    local field="$2"
    local value="$3"
    local var_name="${txn}__${field}"

    printf -v "$var_name" '%s' "$value"
}

_config_txn_get() {
    local txn="$1"
    local field="$2"
    local var_name="${txn}__${field}"

    printf '%s' "${!var_name:-}"
}

config_txn_begin() {
    local file="$1"
    local profile="$2"
    local tmp backup txn

    if [ -z "$file" ] || [ -z "$profile" ]; then
        return 1
    fi

    CONFIG_TXN_COUNTER=$((CONFIG_TXN_COUNTER + 1))
    txn="CFG_TXN_${CONFIG_TXN_COUNTER}"

    tmp="$(_config_file_make_tmp_path "$file")" || return 1
    backup="$(_config_file_make_backup_path "$file")" || return 1

    if [ -e "$file" ]; then
        fs_copy "$file" "$tmp" || return 1
    else
        : > "$tmp" || return 1
    fi

    _config_txn_set "$txn" "FILE" "$file"
    _config_txn_set "$txn" "TMP" "$tmp"
    _config_txn_set "$txn" "BACKUP" "$backup"
    _config_txn_set "$txn" "PROFILE" "$profile"

    printf "%s
" "$txn"
}

config_txn_abort() {
    local txn="$1"
    local tmp

    tmp="$(_config_txn_get "$txn" "TMP")"
    [ -n "$tmp" ] && [ -e "$tmp" ] && fs_remove "$tmp"
}

config_txn_commit() {
    local txn="$1"
    local file tmp backup dir create_backup

    file="$(_config_txn_get "$txn" "FILE")"
    tmp="$(_config_txn_get "$txn" "TMP")"
    backup="$(_config_txn_get "$txn" "BACKUP")"
    create_backup="${CONFIG_FILE_CREATE_BACKUP:-1}"

    if [ -z "$file" ] || [ -z "$tmp" ] || [ ! -e "$tmp" ]; then
        return 1
    fi

    dir="$(dirname "$file")"
    [ -d "$dir" ] || fs_mkdir "$dir" || return 1

    if [ "$create_backup" = "1" ] && [ -e "$file" ]; then
        [ -n "$backup" ] || backup="$(_config_file_make_backup_path "$file")" || return 1
        fs_copy "$file" "$backup" || return 1
    fi

    fs_move "$tmp" "$file" || return 1
}

_config_profile_comment_prefix() {
    local txn="$1"
    local profile
    profile="$(_config_txn_get "$txn" "PROFILE")"
    config_profile_get "$profile" "COMMENT_PREFIX"
}

_config_profile_kv_style() {
    local txn="$1"
    local profile
    profile="$(_config_txn_get "$txn" "PROFILE")"
    config_profile_get "$profile" "KV_STYLE"
}

_config_profile_write_style() {
    local txn="$1"
    local profile
    profile="$(_config_txn_get "$txn" "PROFILE")"
    config_profile_get "$profile" "WRITE_STYLE"
}

_config_escape_regex_basic() {
    command_run_capture sed 's/[][\\.^$*]/\\&/g' <<< "$1"
}

_config_escape_sed_replacement() {
    command_run_capture sed 's/[\/&]/\\&/g' <<< "$1"
}

_config_build_canonical_line() {
    local txn="$1"
    local key="$2"
    local value="$3"
    local write_style

    write_style="$(_config_profile_write_style "$txn")"
    [ -z "$write_style" ] && write_style="spaced_equals"

    case "$write_style" in
        spaced_equals)
            printf '%s = %s\n' "$key" "$value"
            ;;
        equals)
            printf '%s=%s\n' "$key" "$value"
            ;;
        single_space)
            printf '%s %s\n' "$key" "$value"
            ;;
        *)
            printf '%s = %s\n' "$key" "$value"
            ;;
    esac
}

_config_active_match_regex() {
    local txn="$1"
    local key="$2"
    local key_esc kv_style comment_prefix

    key_esc="$(_config_escape_regex_basic "$key")"
    kv_style="$(_config_profile_kv_style "$txn")"
    comment_prefix="$(_config_profile_comment_prefix "$txn")"

    if [ -n "$comment_prefix" ]; then
        comment_prefix="$(_config_escape_regex_basic "$comment_prefix")"
    fi

    case "$kv_style" in
        equals)
            printf '^[[:space:]]*%s[[:space:]]*=[[:space:]]*.*$' "$key_esc"
            ;;
        space)
            printf '^[[:space:]]*%s[[:space:]]+.*$' "$key_esc"
            ;;
        *)
            printf '^[[:space:]]*%s[[:space:]]*=[[:space:]]*.*$' "$key_esc"
            ;;
    esac
}

_config_commented_match_regex() {
    local txn="$1"
    local key="$2"
    local key_esc kv_style comment_prefix_esc comment_prefix

    key_esc="$(_config_escape_regex_basic "$key")"
    kv_style="$(_config_profile_kv_style "$txn")"
    comment_prefix="$(_config_profile_comment_prefix "$txn")"
    comment_prefix_esc="$(_config_escape_regex_basic "$comment_prefix")"

    case "$kv_style" in
        equals)
            printf '^[[:space:]]*%s[[:space:]]*%s[[:space:]]*=[[:space:]]*.*$' \
                "$comment_prefix_esc" "$key_esc"
            ;;
        space)
            printf '^[[:space:]]*%s[[:space:]]*%s[[:space:]]+.*$' \
                "$comment_prefix_esc" "$key_esc"
            ;;
        *)
            printf '^[[:space:]]*%s[[:space:]]*%s[[:space:]]*=[[:space:]]*.*$' \
                "$comment_prefix_esc" "$key_esc"
            ;;
    esac
}

config_has_kv() {
    local txn="$1"
    local key="$2"
    local tmp regex

    tmp="$(_config_txn_get "$txn" "TMP")"
    regex="$(_config_active_match_regex "$txn" "$key")"

    command_run_quiet grep -E -q "$regex" "$tmp"
}

config_set_kv() {
    local txn="$1"
    local key="$2"
    local value="$3"
    local tmp active_regex canonical repl active_count

    tmp="$(_config_txn_get "$txn" "TMP")"
    [ -n "$tmp" ] || return 1

    active_count="$(_config_count_active_kv "$txn" "$key")" || return 1

    case "$active_count" in
        0)
            canonical="$(_config_build_canonical_line "$txn" "$key" "$value")"
            printf '%s' "$canonical" >> "$tmp" || return 1
            return 0
            ;;
        1)
            active_regex="$(_config_active_match_regex "$txn" "$key")"
            canonical="$(_config_build_canonical_line "$txn" "$key" "$value")"
            repl="$(_config_escape_sed_replacement "$(printf '%s' "$canonical" | tr -d '\n')")"

            command_run_capture sed "0,/$active_regex/s~$active_regex~$repl~" \
                "$tmp" > "${tmp}.new" || return 1
            fs_move "${tmp}.new" "$tmp" || return 1
            return 0
            ;;
        *)
            log_error config_file "config_set_kv: multiple active entries for key '${key}'"
            return 1
            ;;
    esac
}

config_comment_kv() {
    local txn="$1"
    local key="$2"
    local tmp active_regex comment_prefix comment_prefix_esc active_count

    tmp="$(_config_txn_get "$txn" "TMP")"
    [ -n "$tmp" ] || return 1

    active_count="$(_config_count_active_kv "$txn" "$key")" || return 1
    comment_prefix="$(_config_profile_comment_prefix "$txn")"
    comment_prefix_esc="$(_config_escape_sed_replacement "$comment_prefix")"

    [ -n "$comment_prefix" ] || return 1

    case "$active_count" in
        0)
            log_error config_file "config_comment_kv: no active entry for key '${key}'"
            return 1
            ;;
        1)
            active_regex="$(_config_active_match_regex "$txn" "$key")"
            command_run_capture sed "0,/$active_regex/{/$active_regex/s~^[[:space:]]*~&$comment_prefix_esc ~}" "$tmp" > "${tmp}.new" || return 1

            fs_move "${tmp}.new" "$tmp" || return 1
            return 0
            ;;
        *)
            log_error config_file "config_comment_kv: multiple active entries for key '${key}'"
            return 1
            ;;
    esac
}

config_uncomment_kv() {
    local txn="$1"
    local key="$2"
    local tmp commented_regex comment_prefix_esc active_count commented_count

    tmp="$(_config_txn_get "$txn" "TMP")"
    [ -n "$tmp" ] || return 1

    active_count="$(_config_count_active_kv "$txn" "$key")" || return 1
    commented_count="$(_config_count_commented_kv "$txn" "$key")" || return 1
    comment_prefix_esc="$(_config_escape_regex_basic "$(_config_profile_comment_prefix "$txn")")"

    case "$active_count:$commented_count" in
        0:1)
            commented_regex="$(_config_commented_match_regex "$txn" "$key")"
            command_run_capture sed "0,/$commented_regex/{/$commented_regex/s~^([[:space:]]*)$comment_prefix_esc[[:space:]]*~\\1~}" "$tmp" > "${tmp}.new" || return 1

            fs_move "${tmp}.new" "$tmp" || return 1
            return 0
            ;;
        0:0)
            log_error config_file "config_uncomment_kv: no commented entry for key '${key}'"
            return 1
            ;;
        0:*)
            log_error config_file "config_uncomment_kv: multiple commented entries for key '${key}'"
            return 1
            ;;
        *)
            log_error config_file "config_uncomment_kv: active entry already exists for key '${key}'"
            return 1
            ;;
    esac
}

config_remove_active_kv() {
    local txn="$1"
    local key="$2"
    local tmp active_regex active_count

    tmp="$(_config_txn_get "$txn" "TMP")"
    [ -n "$tmp" ] || return 1

    active_count="$(_config_count_active_kv "$txn" "$key")" || return 1

    case "$active_count" in
        0)
            log_error config_file "config_remove_active_kv: no active entry for key '${key}'"
            return 1
            ;;
        1)
            active_regex="$(_config_active_match_regex "$txn" "$key")"
            command_run_capture sed "/$active_regex/d" "$tmp" > "${tmp}.new" || return 1
            fs_move "${tmp}.new" "$tmp" || return 1
            return 0
            ;;
        *)
            log_error config_file "config_remove_active_kv: multiple active entries for key '${key}'"
            return 1
            ;;
    esac
}


_config_file_make_backup_path() {
    local target_file="$1"
    local prefix suffix

    prefix="${CONFIG_FILE_BACKUP_PREFIX:-}"
    suffix="${CONFIG_FILE_BACKUP_SUFFIX:-.bak}"

    printf '%s' "${target_file}${prefix}${suffix}"
}

config_file_cleanup_temp_artifacts() {
    local target_file="$1"
    local dir base prefix suffix file

    dir="$(dirname "$target_file")" || return 1
    base="$(basename "$target_file")" || return 1
    prefix="${CONFIG_FILE_TMP_PREFIX:-config_file_txn_}"
    suffix="${CONFIG_FILE_TMP_SUFFIX:-.tmp}"

    [ -d "$dir" ] || return 1

    for file in "${dir}/${base}.${prefix}"*"${suffix}"; do
        [ -e "$file" ] || continue
        fs_remove "$file" || return 1
    done

    return 0
}

_config_file_make_tmp_path() {
    local target_file="$1"
    local dir base prefix suffix

    dir="$(dirname "$target_file")" || return 1
    base="$(basename "$target_file")" || return 1

    prefix="${CONFIG_FILE_TMP_PREFIX:-config_file_txn_}"
    suffix="${CONFIG_FILE_TMP_SUFFIX:-.tmp}"

    [ -d "$dir" ] || return 1

    command_run_capture mktemp "${dir}/${base}.${prefix}XXXXXX${suffix}"
}

_config_count_active_kv() {
    local txn="$1"
    local key="$2"
    local tmp regex

    tmp="$(_config_txn_get "$txn" "TMP")"
    [ -n "$tmp" ] || {
        printf '%s' 0
        return 0
    }

    regex="$(_config_active_match_regex "$txn" "$key")"
    command_run_capture grep -E -c "$regex" "$tmp"
}

_config_count_commented_kv() {
    local txn="$1"
    local key="$2"
    local tmp regex

    tmp="$(_config_txn_get "$txn" "TMP")"
    [ -n "$tmp" ] || {
        printf '%s' 0
        return 0
    }

    regex="$(_config_commented_match_regex "$txn" "$key")"
    command_run_capture grep -E -c "$regex" "$tmp"
}