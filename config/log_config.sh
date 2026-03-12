#!/usr/bin/env bash

###############################################################################
# log_config.sh
#
# Logging configuration for the Bash TUI project.
#
# DESIGN
# ------
# - LOG_ENABLED is a global master switch.
# - Each stream has:
#     - ENABLED flag
#     - LEVEL threshold
#     - FILE destination
# - LOG_STREAM_NAMES explicitly lists all known streams.
# - Relative paths are allowed and expected by default.
# - Absolute paths may also be used.
#
# LEVELS
# ------
# Supported levels (least to most severe):
#   info
#   notice
#   warn
#   error
#
# Threshold rule:
# A stream logs messages at its configured level or higher severity.
###############################################################################

# Global master switch
#   1 = logging enabled
#   0 = logging disabled
LOG_ENABLED=1

###############################################################################
# STREAM REGISTRY
#
# All configured streams must be listed here.
###############################################################################

LOG_STREAM_NAMES=(
    audit
    menu
    workflow
    input
)

###############################################################################
# DEFAULT STREAMS
#
# Policy:
# - audit stays enabled in normal operation
# - debugging streams default to disabled
###############################################################################

LOG_STREAM_audit_ENABLED=1
LOG_STREAM_audit_LEVEL="info"
LOG_STREAM_audit_FILE="logs/audit.log"

LOG_STREAM_menu_ENABLED=0
LOG_STREAM_menu_LEVEL="notice"
LOG_STREAM_menu_FILE="logs/menu.log"

LOG_STREAM_workflow_ENABLED=0
LOG_STREAM_workflow_LEVEL="notice"
LOG_STREAM_workflow_FILE="logs/workflow.log"

LOG_STREAM_input_ENABLED=0
LOG_STREAM_input_LEVEL="warn"
LOG_STREAM_input_FILE="logs/input.log"