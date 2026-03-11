#!/usr/bin/env bash
# composer.sh - Composer info (data only)

get_composer_status() {
    if command -v composer >/dev/null 2>&1; then
        echo "installed"
    else
        echo "not installed"
    fi
}

get_composer_version() {
    command -v composer >/dev/null 2>&1 && composer --version | awk '{print $3}' || echo "n/a"
}