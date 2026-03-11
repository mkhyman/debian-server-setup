#!/usr/bin/env bash
# system.sh - basic system operations

get_system_time() {
    date '+%H:%M:%S'
}

set_system_time() {
    local new_time="$1"
    sudo date -s "$new_time"
}

get_system_date() {
    date '+%Y-%m-%d'
}

set_system_date() {
    local new_date="$1"
    sudo date -s "$new_date"
}