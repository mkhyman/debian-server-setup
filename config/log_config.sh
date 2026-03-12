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
# - Unknown streams are ignored by the logger.
# - Logging is append-only, single-line text.
#
# LEVELS
# ------
# Supported levels, from least severe to most severe:
#   info
#   notice
#   warn
#   error
#
# Threshold behavior:
# - A stream logs messages at its configured level or higher severity.
#
# Example:
#   LOG_STREAM_menu_LEVEL="notice"
# means:
#   notice, warn, error are written
#   info is ignored
###############################################################################

# Global master switch:
#   1 = logging enabled
#   0 = logging disabled
LOG_ENABLED=1

###############################################################################
# STREAM CONFIGURATION
#
# Convention:
#   LOG_STREAM_<name>_ENABLED=0|1
#   LOG_STREAM_<name>_LEVEL="info|notice|warn|error"
#   LOG_STREAM_<name>_FILE="/path/to/file"
#
# Suggested policy:
# - audit stays enabled in normal operation
# - noisy/debug-style streams default to disabled
###############################################################################

# Audit log:
# Important operational record of actions taken by the application.
LOG_STREAM_audit_ENABLED=1
LOG_STREAM_audit_LEVEL="info"
LOG_STREAM_audit_FILE="./logs/audit.log"

# Menu log:
# Useful for debugging menu navigation and lifecycle handlers.
LOG_STREAM_menu_ENABLED=0
LOG_STREAM_menu_LEVEL="notice"
LOG_STREAM_menu_FILE="./logs/menu.log"

# Workflow log:
# Useful for debugging workflow execution and step transitions.
LOG_STREAM_workflow_ENABLED=0
LOG_STREAM_workflow_LEVEL="notice"
LOG_STREAM_workflow_FILE="./logs/workflow.log"

# Input log:
# Usually noisy, so off by default.
LOG_STREAM_input_ENABLED=0
LOG_STREAM_input_LEVEL="warn"
LOG_STREAM_input_FILE="./logs/input.log"