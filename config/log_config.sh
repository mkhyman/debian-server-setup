#!/usr/bin/env bash

# Global master switch
# 1 = logging enabled
# 0 = logging disabled
LOG_ENABLED=1

# Optional debug pane mirroring
# Disabled by default
LOG_DEBUG_PANE_ENABLED=0
LOG_DEBUG_PANE_ID=3

# All streams must be listed here
LOG_STREAM_NAMES=(
    audit
    core
    menu
    workflow
    input
    debug
)

# Audit stream
# Intended for operational history such as user deletion
LOG_STREAM_audit_ENABLED=1
LOG_STREAM_audit_LEVEL="info"
LOG_STREAM_audit_FILE="logs/audit.log"

# Core lifecycle logging
LOG_STREAM_core_ENABLED=0
LOG_STREAM_core_LEVEL="notice"
LOG_STREAM_core_FILE="logs/core.log"

# Menu navigation
LOG_STREAM_menu_ENABLED=0
LOG_STREAM_menu_LEVEL="notice"
LOG_STREAM_menu_FILE="logs/menu.log"

# Workflow execution
LOG_STREAM_workflow_ENABLED=0
LOG_STREAM_workflow_LEVEL="notice"
LOG_STREAM_workflow_FILE="logs/workflow.log"

# Input system
LOG_STREAM_input_ENABLED=0
LOG_STREAM_input_LEVEL="warn"
LOG_STREAM_input_FILE="logs/input.log"

# Debug stream (disabled by default)
# Can be enabled temporarily during development
LOG_STREAM_debug_ENABLED=0
LOG_STREAM_debug_LEVEL="info"
LOG_STREAM_debug_FILE="logs/debug.log"