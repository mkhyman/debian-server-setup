#!/usr/bin/env bash

###############################################################################
# tui_menu.sh
#
# Flat menu system for a pane-based Bash TUI.
#
# DESIGN SUMMARY
# --------------
# - Menus are defined as flat data.
# - Menu navigation state has exactly one authoritative source:
#       MENU_STACK
# - MENU_STACK is never empty after menu_init().
# - MENU_STACK[0] is the top-level menu.
# - MENU_STACK[last] is the current menu.
# - There is no separate CURRENT_MENU or ROOT_MENU variable.
# - Menu items support two configured actions only:
#       menu
#       workflow
# - Menu labels may be:
#       literal:<text>
#       func:<function_name>
# - Label functions must print to stdout only.
# - This file captures all such stdout before appending to a pane.
# - This file never writes directly to the terminal.
# - One automatic final menu item is always rendered:
#       top level -> Quit
#       submenu   -> Back
# - Optional per-menu lifecycle handlers are supported:
#       MENU_<NAME>_ON_ENTER
#       MENU_<NAME>_ON_BACK
# - Handler failure behavior is globally configurable:
#       MENU_STRICT_HANDLERS=1   # default, block navigation on failure
#       MENU_STRICT_HANDLERS=0   # ignore handler failures
#
# EXPECTED EXTERNAL DEPENDENCIES
# ------------------------------
# Required:
#   pane_clear <pane_id>
#   pane_append <pane_id> <text>
#   workflow_start <workflow_name>
#
# Optional:
#   quit_application
#
# MENU DEFINITION FORMAT
# ----------------------
#   MENU_<NAME>_TITLE="Some title"
#   MENU_<NAME>_ITEMS=(
#       "label_spec|action|target"
#       ...
#   )
#
# label_spec:
#   literal:Static text
#   func:function_name_that_prints_text
#
# action:
#   menu
#   workflow
#
# target:
#   if action=menu:
#       target is another menu name
#
#   if action=workflow:
#       target is the workflow array name passed to workflow_start
#
# OPTIONAL MENU LIFECYCLE HANDLERS
# --------------------------------
#   MENU_<NAME>_ON_ENTER="some_function"
#   MENU_<NAME>_ON_BACK="some_function"
#
# Handler calling convention:
#   some_function "<menu_name>"
#
# ENTER handler:
#   Runs whenever a menu becomes the active menu, including:
#   - menu_init
#   - menu_open
#   - menu_go_back (for the menu being returned to)
#
# BACK handler:
#   Runs only when leaving the current menu via Back.
#
# IMPORTANT ITEM LIMIT
# --------------------
# Slot 9 is reserved for the automatic final item (Back/Quit).
# Therefore each menu should define at most 8 configured items.
#
# FUTURE LOGGING HOOKS
# --------------------
# There are several places in this file where future logging will be useful:
# - missing menu definition
# - missing label function
# - missing lifecycle handler
# - lifecycle handler returning failure
# - missing quit_application
# - invalid configured action
# - invalid numeric selection
# - workflow_start failure
#
# These locations are marked with "LOGGING CANDIDATE" comments below.
###############################################################################

###############################################################################
# GLOBAL STATE
###############################################################################

# Pane ID used to render the menu.
MENU_PANE_ID=1

# Authoritative menu navigation state.
# Invariant after menu_init():
# - MENU_STACK has at least one element
# - MENU_STACK[0] is the top-level menu
# - MENU_STACK[last] is the current menu
MENU_STACK=()

# Global handler policy:
#   1 = strict  -> handler failure blocks navigation
#   0 = relaxed -> handler failure is ignored
MENU_STRICT_HANDLERS=1

###############################################################################
# BASIC STATE HELPERS
###############################################################################

# menu_stack_size
# ---------------
# Print the number of menu names currently on the stack.
menu_stack_size() {
    printf '%s' "${#MENU_STACK[@]}"
}

# menu_current
# ------------
# Print the current menu name, i.e. the last element of MENU_STACK.
#
# Return:
#   0 on success
#   1 if MENU_STACK is empty
menu_current() {
    local count=${#MENU_STACK[@]}

    (( count > 0 )) || return 1
    printf '%s' "${MENU_STACK[count-1]}"
}

# menu_top
# --------
# Print the top-level menu name, i.e. the first element of MENU_STACK.
#
# Return:
#   0 on success
#   1 if MENU_STACK is empty
menu_top() {
    local count=${#MENU_STACK[@]}

    (( count > 0 )) || return 1
    printf '%s' "${MENU_STACK[0]}"
}

# menu_is_top_level
# -----------------
# Return success if the current menu is also the top-level menu.
menu_is_top_level() {
    (( ${#MENU_STACK[@]} == 1 ))
}

# menu_can_go_back
# ----------------
# Return success if there is a previous menu to go back to.
menu_can_go_back() {
    (( ${#MENU_STACK[@]} > 1 ))
}

# menu_should_enforce_handler_success
# -----------------------------------
# Return success when handler failures should block navigation.
#
# Default is strict mode unless explicitly disabled.
menu_should_enforce_handler_success() {
    [[ "${MENU_STRICT_HANDLERS:-1}" == "1" ]]
}

###############################################################################
# MENU DEFINITION ACCESS
###############################################################################

# menu_exists
# -----------
# A menu is considered defined if either its TITLE variable or ITEMS variable
# exists. This allows title-less menus, item-less menus, or both.
#
# Args:
#   $1 = menu name
#
# Return:
#   0 if defined
#   1 if not defined
menu_exists() {
    local menu_name="$1"
    local title_var="MENU_${menu_name}_TITLE"
    local items_var="MENU_${menu_name}_ITEMS"

    if [[ -n "${!title_var+x}" || -n "${!items_var+x}" ]]; then
        return 0
    fi

    # LOGGING CANDIDATE:
    # Missing menu definition.
    return 1
}

# menu_get_title
# --------------
# Print the title for a menu, or an empty string if no title is defined.
#
# Args:
#   $1 = menu name
menu_get_title() {
    local menu_name="$1"
    local title_var="MENU_${menu_name}_TITLE"

    printf '%s' "${!title_var}"
}

# menu_get_item_count
# -------------------
# Print the number of configured items for a menu.
# This does NOT include the automatic Back/Quit item.
#
# Args:
#   $1 = menu name
menu_get_item_count() {
    local menu_name="$1"
    local items_var="MENU_${menu_name}_ITEMS[@]"
    local items=("${!items_var}")

    printf '%s' "${#items[@]}"
}

# menu_get_item_entry
# -------------------
# Print one raw configured item entry by zero-based index.
#
# Args:
#   $1 = menu name
#   $2 = zero-based index
#
# Return:
#   0 on success
#   1 if index is out of range
menu_get_item_entry() {
    local menu_name="$1"
    local index="$2"
    local items_var="MENU_${menu_name}_ITEMS[@]"
    local items=("${!items_var}")

    if (( index < 0 || index >= ${#items[@]} )); then
        # LOGGING CANDIDATE:
        # Invalid configured item index.
        return 1
    fi

    printf '%s' "${items[index]}"
}

# menu_get_on_enter_handler
# -------------------------
# Print the configured enter handler function name for a menu, if any.
#
# Args:
#   $1 = menu name
menu_get_on_enter_handler() {
    local menu_name="$1"
    local var_name="MENU_${menu_name}_ON_ENTER"

    printf '%s' "${!var_name}"
}

# menu_get_on_back_handler
# ------------------------
# Print the configured back handler function name for a menu, if any.
#
# Args:
#   $1 = menu name
menu_get_on_back_handler() {
    local menu_name="$1"
    local var_name="MENU_${menu_name}_ON_BACK"

    printf '%s' "${!var_name}"
}

###############################################################################
# LABEL RESOLUTION
###############################################################################

# menu_missing_function_text
# --------------------------
# Produce placeholder text for a missing function reference.
#
# Args:
#   $1 = function name
menu_missing_function_text() {
    local func_name="$1"
    printf '[missing function: %s]' "$func_name"
}

# menu_resolve_label
# ------------------
# Resolve a label spec into visible text.
#
# Supported formats:
#   literal:Some text
#   func:some_function_name
#
# Rules:
# - This function must not write directly to the terminal.
# - Dynamic label functions must print to stdout only.
# - The caller should capture this function's stdout before passing it to
#   pane_append.
#
# Args:
#   $1 = label spec
#
# Output:
#   Prints resolved label text
menu_resolve_label() {
    local label_spec="$1"
    local kind=""
    local value=""

    kind="${label_spec%%:*}"
    value="${label_spec#*:}"

    case "$kind" in
        literal)
            printf '%s' "$value"
            ;;

        func)
            if declare -F "$value" >/dev/null 2>&1; then
                "$value"
            else
                # LOGGING CANDIDATE:
                # Missing dynamic label function.
                menu_missing_function_text "$value"
            fi
            ;;

        *)
            # Unknown label prefix: treat the whole field as literal text.
            # LOGGING CANDIDATE:
            # Unknown label spec format.
            printf '%s' "$label_spec"
            ;;
    esac
}

###############################################################################
# LIFECYCLE HANDLERS
###############################################################################

# menu_run_handler
# ----------------
# Execute an optional menu lifecycle handler according to the global strictness
# policy.
#
# Args:
#   $1 = handler function name (may be empty)
#   $2 = menu name passed to the handler
#
# Behavior:
# - Empty handler name is treated as success.
# - Missing handler function returns failure in strict mode, success in relaxed.
# - Non-zero handler exit code returns failure in strict mode, success in
#   relaxed mode.
#
# Return:
#   0 if handler is considered successful under current policy
#   non-zero if strict mode is enabled and the handler failed
menu_run_handler() {
    local handler_name="$1"
    local menu_name="$2"
    local rc=0

    [[ -n "$handler_name" ]] || return 0

    if ! declare -F "$handler_name" >/dev/null 2>&1; then
        # LOGGING CANDIDATE:
        # Missing lifecycle handler function.
        if menu_should_enforce_handler_success; then
            return 1
        fi
        return 0
    fi

    "$handler_name" "$menu_name"
    rc=$?

    if (( rc != 0 )); then
        # LOGGING CANDIDATE:
        # Lifecycle handler failed. Log handler name, menu name, rc, and phase.
        if menu_should_enforce_handler_success; then
            return "$rc"
        fi
        return 0
    fi

    return 0
}

# menu_call_on_enter
# ------------------
# Call the ON_ENTER handler for a menu, if one is configured.
#
# Args:
#   $1 = menu name
menu_call_on_enter() {
    local menu_name="$1"
    local handler_name=""

    handler_name="$(menu_get_on_enter_handler "$menu_name")"
    menu_run_handler "$handler_name" "$menu_name"
}

# menu_call_on_back
# -----------------
# Call the ON_BACK handler for a menu, if one is configured.
#
# Args:
#   $1 = menu name
menu_call_on_back() {
    local menu_name="$1"
    local handler_name=""

    handler_name="$(menu_get_on_back_handler "$menu_name")"
    menu_run_handler "$handler_name" "$menu_name"
}

###############################################################################
# AUTO-GENERATED FINAL ITEM
###############################################################################

# menu_real_item_limit
# --------------------
# Maximum number of configured items that may be displayed.
# Slot 9 is reserved for the automatic final item.
menu_real_item_limit() {
    printf '8'
}

# menu_get_visible_real_count
# ---------------------------
# Print the number of configured items that will actually be rendered.
# This is capped at the real item limit.
#
# Args:
#   $1 = menu name
menu_get_visible_real_count() {
    local menu_name="$1"
    local count=0
    local limit=0

    count="$(menu_get_item_count "$menu_name")"
    limit="$(menu_real_item_limit)"

    if (( count > limit )); then
        count=$limit
    fi

    printf '%s' "$count"
}

# menu_get_visible_count
# ----------------------
# Print total visible item count, including the auto-generated Back/Quit item.
#
# Args:
#   $1 = menu name
menu_get_visible_count() {
    local menu_name="$1"
    local real_count=0

    real_count="$(menu_get_visible_real_count "$menu_name")"
    printf '%s' "$(( real_count + 1 ))"
}

# menu_auto_item_label
# --------------------
# Print the automatically generated final item's label.
# - Quit at top level
# - Back in submenus
menu_auto_item_label() {
    if menu_is_top_level; then
        printf 'Quit'
    else
        printf 'Back'
    fi
}

###############################################################################
# RENDERING
###############################################################################

# menu_render
# -----------
# Render a named menu into the configured menu pane.
#
# Rendering order:
#   1. clear menu pane
#   2. append title if present
#   3. append divider if title present
#   4. append configured items (up to 8)
#   5. append automatic final item (Back/Quit)
#
# Args:
#   $1 = menu name
#
# Return:
#   0 on success
#   1 if the menu does not exist
menu_render() {
    local menu_name="$1"
    local title=""
    local items_var="MENU_${menu_name}_ITEMS[@]"
    local items=()
    local visible_real_count=0
    local auto_label=""
    local entry=""
    local label_spec=""
    local action=""
    local target=""
    local label=""

    if ! menu_exists "$menu_name"; then
        # LOGGING CANDIDATE:
        # Attempted render of undefined menu.
        return 1
    fi

    title="$(menu_get_title "$menu_name")"
    items=("${!items_var}")
    visible_real_count="$(menu_get_visible_real_count "$menu_name")"

    pane_clear "$MENU_PANE_ID"

    if [[ -n "$title" ]]; then
        pane_append "$MENU_PANE_ID" "$title"
        pane_append "$MENU_PANE_ID" "--------------------"
    fi

    local i=0
    for (( i=0; i<visible_real_count; i++ )); do
        entry="${items[i]}"
        IFS='|' read -r label_spec action target <<< "$entry"

        # Important:
        # Dynamic label output is captured here. No direct terminal writes.
        label="$(menu_resolve_label "$label_spec")"
        pane_append "$MENU_PANE_ID" "$((i+1)). $label"
    done

    auto_label="$(menu_auto_item_label)"
    if menu_is_top_level; then
        pane_append "$MENU_PANE_ID" "Q. $auto_label"
    else
        pane_append "$MENU_PANE_ID" "B. $auto_label"
    fi

    return 0
}

# menu_refresh
# ------------
# Re-render the current menu.
#
# Useful after workflows change state that affects label functions.
menu_refresh() {
    local current_menu=""

    current_menu="$(menu_current)" || return 1
    menu_render "$current_menu"
}

###############################################################################
# NAVIGATION
###############################################################################

# menu_init
# ---------
# Initialize the menu system with one top-level menu.
#
# Behavior:
# - Validates the initial menu
# - Resets MENU_STACK to contain exactly that menu
# - Calls the menu's ON_ENTER handler
# - Renders the menu
#
# Args:
#   $1 = initial menu name
#
# Return:
#   0 on success
#   1 on failure
menu_init() {
    local initial_menu="$1"

    menu_exists "$initial_menu" || return 1

    MENU_STACK=("$initial_menu")

    menu_call_on_enter "$initial_menu" || return 1
    menu_render "$initial_menu"
}

# menu_open
# ---------
# Navigate forward into another menu.
#
# Behavior:
# - Validates target menu
# - Pushes target menu onto MENU_STACK
# - Calls target menu's ON_ENTER handler
# - Renders target menu
#
# Args:
#   $1 = target menu name
#
# Return:
#   0 on success
#   1 on failure
menu_open() {
    local target_menu="$1"

    menu_exists "$target_menu" || return 1

    MENU_STACK+=("$target_menu")

    if ! menu_call_on_enter "$target_menu"; then
        # Enter failed: revert the push to keep stack consistent.
        unset 'MENU_STACK[${#MENU_STACK[@]}-1]'
        MENU_STACK=("${MENU_STACK[@]}")

        # LOGGING CANDIDATE:
        # ON_ENTER failed for target menu during forward navigation.
        return 1
    fi

    menu_render "$target_menu"
}

# menu_go_back
# ------------
# Navigate back one level.
#
# Behavior:
# - Fails if already at top level
# - Calls current menu's ON_BACK handler before leaving
# - Pops current menu from MENU_STACK
# - Calls the new current menu's ON_ENTER handler
# - Renders the newly current menu
#
# Important:
# - In strict mode, ON_BACK failure blocks leaving the menu
# - In strict mode, ON_ENTER failure after pop is treated as fatal for the
#   navigation attempt; the stack is restored to preserve consistency
#
# Return:
#   0 on success
#   1 on failure
menu_go_back() {
    local count=${#MENU_STACK[@]}
    local leaving_menu=""
    local destination_menu=""

    (( count > 1 )) || return 1

    leaving_menu="${MENU_STACK[count-1]}"
    destination_menu="${MENU_STACK[count-2]}"

    if ! menu_call_on_back "$leaving_menu"; then
        # LOGGING CANDIDATE:
        # ON_BACK failed for current menu.
        return 1
    fi

    unset 'MENU_STACK[count-1]'
    MENU_STACK=("${MENU_STACK[@]}")

    if ! menu_call_on_enter "$destination_menu"; then
        # Restore the previous state if the destination menu cannot be entered.
        MENU_STACK+=("$leaving_menu")

        # LOGGING CANDIDATE:
        # Destination ON_ENTER failed during back-navigation.
        return 1
    fi

    menu_render "$destination_menu"
}

# go_back_in_menu
# ---------------
# Semantic wrapper useful to workflows and input handling.
go_back_in_menu() {
    menu_go_back
}

###############################################################################
# DISPATCH
###############################################################################

# menu_dispatch_configured_item
# -----------------------------
# Dispatch a configured menu item.
#
# Entry format:
#   label_spec|action|target
#
# Supported actions:
#   menu
#   workflow
#
# Args:
#   $1 = raw entry string
#
# Return:
#   0 on success
#   1 on failure
menu_dispatch_configured_item() {
    local entry="$1"
    local label_spec=""
    local action=""
    local target=""

    IFS='|' read -r label_spec action target <<< "$entry"

    case "$action" in
        menu)
            menu_open "$target" || return 1
            ;;

        workflow)
            workflow_start "$target" || return 1
            # LOGGING CANDIDATE:
            # If this fails, log workflow name and current menu.
            ;;

        *)
            # LOGGING CANDIDATE:
            # Unknown configured action in menu entry.
            return 1
            ;;
    esac

    return 0
}

# menu_dispatch_auto_item
# -----------------------
# Dispatch the auto-generated final item.
#
# Behavior:
# - top level -> quit_application
# - submenu   -> menu_go_back
#
# Return:
#   0 on success
#   1 on failure
menu_dispatch_auto_item() {
    if menu_is_top_level; then
        if ! declare -F quit_application >/dev/null 2>&1; then
            # LOGGING CANDIDATE:
            # Quit requested but quit_application is missing.
            return 1
        fi
        quit_application
    else
        menu_go_back || return 1
    fi
}

# select_menu_item
# ----------------
# Handle numeric menu selection for the current menu.
#
# Visible numbering:
# - configured items occupy slots 1..N
# - auto Back/Quit occupies slot N+1
#
# Args:
#   $1 = key, expected "1".."9"
#
# Return:
#   0 if handled
#   1 if invalid or out of range
select_menu_item() {
    local key="$1"
    local current_menu=""
    local visible_real_count=0
    local index=0
    local entry=""

    [[ "$key" =~ ^[1-9]$ ]] || return 1

    current_menu="$(menu_current)" || return 1
    visible_real_count="$(menu_get_visible_real_count "$current_menu")"

    index=$(( key - 1 ))

    if (( index < visible_real_count )); then
        entry="$(menu_get_item_entry "$current_menu" "$index")" || return 1
        menu_dispatch_configured_item "$entry" || return 1
        return 0
    fi

    return 1
}

###############################################################################
# OPTIONAL SHORTCUT HELPERS
###############################################################################

# menu_handle_back_shortcut
# -------------------------
# Handle 'B' style shortcut.
# Only valid when not at top level.
menu_handle_back_shortcut() {
    menu_can_go_back || return 1
    menu_go_back
}

# menu_handle_quit_shortcut
# -------------------------
# Handle 'Q' style shortcut.
# Only valid at top level.
menu_handle_quit_shortcut() {
    menu_is_top_level || return 1

    if ! declare -F quit_application >/dev/null 2>&1; then
        # LOGGING CANDIDATE:
        # Quit shortcut requested but quit_application is missing.
        return 1
    fi

    quit_application
}

###############################################################################
# EXAMPLE DEFINITIONS
#
# These are examples only. Remove or replace them in your project.
###############################################################################

# Example menu definitions:
#
# MENU_MAIN_TITLE="Main Menu"
# MENU_MAIN_ITEMS=(
#     "literal:Network|menu|NETWORK"
#     "literal:Services|menu|SERVICES"
# )
#
# MENU_NETWORK_TITLE="Network"
# MENU_NETWORK_ITEMS=(
#     "func:menu_label_ssh_toggle|workflow|WF_TOGGLE_SSH"
# )
#
# MENU_NETWORK_ON_ENTER="menu_network_on_enter"
# MENU_NETWORK_ON_BACK="menu_network_on_back"
#
# Example label function:
#
# menu_label_ssh_toggle() {
#     if ssh_is_enabled; then
#         printf 'Disable SSH'
#     else
#         printf 'Enable SSH'
#     fi
# }
#
# Example lifecycle handlers:
#
# menu_network_on_enter() {
#     local menu_name="$1"
#     refresh_network_cache
# }
#
# menu_network_on_back() {
#     local menu_name="$1"
#     clear_network_temp_state
# }