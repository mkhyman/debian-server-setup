#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Development trace toggle
# 0 = normal operation
# 1 = enable bash execution trace to logs/os_tool_trace.log
DEBUG_TRACE=0

if (( DEBUG_TRACE )); then
    TRACE_FILE="$SCRIPT_DIR/os_tool_trace.log"
    : > "$TRACE_FILE" || exit 1
    exec 5>>"$TRACE_FILE" || exit 1
    export BASH_XTRACEFD=5
    export PS4='+ ${BASH_SOURCE}:${LINENO}:${FUNCNAME[0]:-main}: '
    set -x
else
    set +x
fi

set -u

# just for debug during development, not intended for production use
mkdir -p logs
exec 2>>runtime-errors.log

###############################################################################
# APP BOOTSTRAP
#
# This file is responsible for assembling the application:
# - source configuration
# - source libraries
# - source modules
# - source menu and workflow definitions
# - initialize panes and menu system
# - run the main input loop
###############################################################################

###############################################################################
# CONFIGURATION
###############################################################################

source "$SCRIPT_DIR/config/app_config.sh"
source "$SCRIPT_DIR/config/log_config.sh"

###############################################################################
# LIBRARIES
###############################################################################

source "$SCRIPT_DIR/lib/log.sh"
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/tui_panes.sh"
source "$SCRIPT_DIR/lib/tui_input.sh"
source "$SCRIPT_DIR/lib/tui_menu.sh"
source "$SCRIPT_DIR/lib/workflow.sh"
source "$SCRIPT_DIR/lib/command.sh"
source "$SCRIPT_DIR/lib/config_file.sh"
source "$SCRIPT_DIR/lib/fs.sh"
source "$SCRIPT_DIR/lib/platform.sh"
source "$SCRIPT_DIR/lib/package.sh"
source "$SCRIPT_DIR/lib/service.sh"
source "$SCRIPT_DIR/lib/system.sh"
source "$SCRIPT_DIR/lib/formatting.sh"

###############################################################################
# CONFIG PROFILES
###############################################################################

source "$SCRIPT_DIR/config_profiles/apache.sh"
source "$SCRIPT_DIR/config_profiles/php_ini.sh"
source "$SCRIPT_DIR/config_profiles/sshd.sh"

###############################################################################
# MODULES
###############################################################################

source "$SCRIPT_DIR/modules/composer_module.sh"
source "$SCRIPT_DIR/modules/php_module.sh"
source "$SCRIPT_DIR/modules/user_module.sh"

###############################################################################
# MENUS
###############################################################################

source "$SCRIPT_DIR/menu/main_menu.sh"
source "$SCRIPT_DIR/menu/user_menu.sh"
source "$SCRIPT_DIR/menu/application_menu.sh"
source "$SCRIPT_DIR/menu/composer_menu.sh"
source "$SCRIPT_DIR/menu/php_menu.sh"

###############################################################################
# INFO PANELS
###############################################################################

source "$SCRIPT_DIR/info/composer_info.sh"
source "$SCRIPT_DIR/info/php_info.sh"

################################################################################
# WORKFLOW IMPLEMENTATIONS
################################################################################

source "$SCRIPT_DIR/workflows/composer_workflow.sh"
source "$SCRIPT_DIR/workflows/php_workflow.sh"

###############################################################################
# STARTUP
###############################################################################

core_startup || exit 1

setup_panes
pane_draw_all
menu_init "MAIN"

###############################################################################
# MAIN LOOP
###############################################################################

log_notice core "Main loop starting"
while true; do
echo "Waiting for key input..." >&2
    key="$(tui_read_key)" || break
    tui_handle_key "$key"
done
log_notice core "Main loop terminated"

exit 0
