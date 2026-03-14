#!/usr/bin/env bash

MENU_PHP_TITLE="PHP Management"

MENU_PHP_ITEMS=(
    "literal:Install PHP version|workflow|WF_PHP_INSTALL"
    "literal:Uninstall PHP version|workflow|WF_PHP_UNINSTALL"
    "literal:Select default CLI version|workflow|WF_PHP_SELECT_DEFAULT_CLI"
)

menu_register "PHP" "${MENU_PHP_ITEMS[@]}"

MENU_PHP_ON_ENTER="menu_php_on_enter"
MENU_PHP_ON_BACK="menu_php_on_back"

menu_php_on_enter() {
    info_render_php
}

menu_php_on_back() {
    pane_clear "$PANE_INFO_ID"
}