#!/usr/bin/env bash

WF_COMPOSER_INSTALL_UNINSTALL_ITEMS=(
    "run|workflow_composer_install_uninstall"
)

workflow_register "WF_COMPOSER_INSTALL_UNINSTALL" "${WF_COMPOSER_INSTALL_UNINSTALL_ITEMS[@]}"

workflow_composer_install_uninstall() {
    pane_set_content "$PANE_ACTION_ID" "Composer install/uninstall workflow not implemented yet."
}
