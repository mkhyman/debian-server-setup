#!/usr/bin/env bash

PANE_SYS_ID=0
PANE_MENU_ID=1
PANE_INFO_ID=2
PANE_ACTION_ID=3

# Temporary file prefix/suffix for config file manipulation transactions
CONFIG_FILE_TMP_PREFIX="os-control-script-config-txn-"
CONFIG_FILE_TMP_SUFFIX=".tmp"

# Create a single rolling backup when committing config file transactions
CONFIG_FILE_CREATE_BACKUP=1
CONFIG_FILE_BACKUP_PREFIX=""
CONFIG_FILE_BACKUP_SUFFIX=".bak"

# Default php modules installed
PHP_DEFAULT_MODULES=(cli common fpm curl mbstring xml zip)
