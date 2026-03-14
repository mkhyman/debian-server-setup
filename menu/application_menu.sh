#!/usr/bin/env bash

MENU_APPLICATION_TITLE="Application Menu"

MENU_APPLICATION_ITEMS=(
    "literal:Composer Management|menu|COMPOSER"
)

menu_register "APPLICATION" "${MENU_APPLICATION_ITEMS[@]}"
