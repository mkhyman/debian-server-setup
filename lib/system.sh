#!/usr/bin/env bash

###############################################################################
# system.sh
#
# PURPOSE
# -------
# Public OS-facing facade used by modules.
#
# Modules should call system_* functions only.
# system.sh delegates to lower-level helpers such as command.sh, package.sh,
# service.sh, config.sh, and fs.sh.
###############################################################################

system_command_run() {
    command_run "$@"
}

system_command_run_capture() {
    command_run_capture "$@"
}

system_command_run_quiet() {
    command_run_quiet "$@"
}

system_command_exists() {
    command_exists "$1"
}

system_command_get_path() {
    command_get_path "$1"
}

system_package_install() {
    package_install "$1"
}

system_package_remove() {
    package_remove "$1"
}

system_package_is_installed() {
    package_is_installed "$1"
}

system_service_start() {
    service_start "$1"
}

system_service_stop() {
    service_stop "$1"
}

system_service_restart() {
    service_restart "$1"
}

system_service_reload() {
    service_reload "$1"
}

system_service_enable() {
    service_enable "$1"
}

system_service_disable() {
    service_disable "$1"
}

system_fs_exists() {
    fs_exists "$1"
}

system_fs_is_file() {
    fs_is_file "$1"
}

system_fs_is_dir() {
    fs_is_dir "$1"
}

system_fs_mkdir() {
    fs_mkdir "$1"
}

system_fs_copy() {
    fs_copy "$1" "$2"
}

system_fs_move() {
    fs_move "$1" "$2"
}

system_fs_remove() {
    fs_remove "$1"
}

system_fs_chmod() {
    fs_chmod "$1" "$2"
}

system_fs_chown() {
    fs_chown "$1" "$2"
}

system_config_begin() {
    config_begin "$@"
}

system_config_commit() {
    config_commit "$@"
}

system_config_abort() {
    config_abort "$@"
}

system_config_set_kv() {
    config_set_kv "$@"
}

system_config_comment_kv() {
    config_comment_kv "$@"
}

system_config_uncomment_kv() {
    config_uncomment_kv "$@"
}

system_config_remove_kv() {
    config_remove_kv "$@"
}

system_config_has_kv() {
    config_has_kv "$@"
}