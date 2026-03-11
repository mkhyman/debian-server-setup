#!/usr/bin/env bash
# docker.sh - Docker service info (data only)

get_docker_installed() {
    if command -v docker >/dev/null 2>&1; then
        echo "installed"
    else
        echo "not installed"
    fi
}

get_docker_running_containers() {
    if ! docker info >/dev/null 2>&1; then
        echo "0"
    else
        docker ps --format '{{.Names}}' | wc -l
    fi
}

get_docker_status() {
    if systemctl is-active --quiet docker 2>/dev/null; then
        echo "running"
    else
        echo "stopped"
    fi
}