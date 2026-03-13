#!/usr/bin/env bash

MENU_APPLICATION_TITLE="Application Menu"

MENU_APPLICATION_ITEMS=(
    "literal:Composer Management|menu|COMPOSER"
)

MENU_APPLICATION_ITEMS_BLOB="$(menu_items_to_blob "${MENU_APPLICATION_ITEMS[@]}")"