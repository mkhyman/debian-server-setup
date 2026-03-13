#!/usr/bin/env bash

MENU_USER_TITLE="User Menu"

MENU_USER_ITEMS=()

MENU_USER_ITEMS_BLOB="$(menu_items_to_blob "${MENU_USER_ITEMS[@]}")"