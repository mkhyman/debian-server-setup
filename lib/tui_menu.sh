#!/usr/bin/env bash

MENU_STACK=()
MENU_STRICT_HANDLERS=1

menu_items_to_blob() {
    local item
    local blob=""

    for item in "$@"; do
        [ -n "$item" ] || continue

        if [ -n "$blob" ]; then
            blob+=$'\n'
        fi

        blob+="$item"
    done

    printf '%s' "$blob"
}

menu_stack_size() {
    printf '%s' "${#MENU_STACK[@]}"
}

menu_current() {
    local count=${#MENU_STACK[@]}
    (( count > 0 )) || return 1
    printf '%s' "${MENU_STACK[count-1]}"
}

menu_is_top_level() {
    (( ${#MENU_STACK[@]} == 1 ))
}

menu_exists() {
    local menu_name="$1"
    local title_var="MENU_${menu_name}_TITLE"
    [[ -n "${!title_var:-}" ]]
}

menu_get_title() {
    local menu_name="$1"
    local title_var="MENU_${menu_name}_TITLE"
    printf '%s' "${!title_var:-}"
}

menu_get_items_blob() {
    local menu_name="$1"
    local var_name="MENU_${menu_name}_ITEMS_BLOB"
    printf '%s' "${!var_name:-}"
}

# menu_get_items() {
#     local menu_name="$1"
#     local var_name="MENU_${menu_name}_ITEMS_BLOB"
#     printf '%s' "${!var_name:-}"
# }

menu_get_item_count() {
    local menu_name="$1"
    local blob
    local count=0
    local line

    blob="$(menu_get_items_blob "$menu_name")"

    [ -n "$blob" ] || {
        printf '%s' 0
        return 0
    }

    while IFS= read -r line; do
        [ -n "$line" ] || continue
        count=$((count + 1))
    done <<< "$blob"

    printf '%s' "$count"
}

menu_real_item_limit() {
    printf '9'
}

menu_get_visible_real_count() {
    local menu_name="$1"
    menu_get_item_count "$menu_name"
}

menu_get_item_entry() {
    local menu_name="$1"
    local target_index="$2"
    local blob
    local index=0
    local line

    blob="$(menu_get_items_blob "$menu_name")"
    [ -n "$blob" ] || return 1

    while IFS= read -r line; do
        [ -n "$line" ] || continue

        if [ "$index" -eq "$target_index" ]; then
            printf '%s' "$line"
            return 0
        fi

        index=$((index + 1))
    done <<< "$blob"

    return 1
}

menu_auto_item_label() {
    if menu_is_top_level; then
        printf 'Quit'
    else
        printf 'Back'
    fi
}

menu_resolve_label() {
    local spec="$1"
    local label
    local func

    case "$spec" in
        literal:*)
            label="${spec#literal:}"
            printf '%s' "$label"
            ;;
        func:*)
            func="${spec#func:}"

            if ! declare -F "$func" >/dev/null 2>&1; then
                log_warn menu "Missing label function ${func}"
                printf '%s' "<missing label>"
                return 1
            fi

            label="$("$func")"
            printf '%s' "$label"
            ;;
        *)
            printf '%s' "$spec"
            ;;
    esac
}

menu_render() {
    local menu_name="$1"
    local title
    local visible_count
    local i
    local entry
    local label_spec
    local action
    local target
    local label
    local auto_label
    local menu_text

    if ! menu_exists "$menu_name"; then
        log_error menu "Attempt to render undefined menu ${menu_name}"
        return 1
    fi

    title="$(menu_get_title "$menu_name")"
    visible_count="$(menu_get_visible_real_count "$menu_name")"

    menu_text="$title"$'\n'
    menu_text+="--------------------"$'\n'

    for ((i=0; i<visible_count; i++)); do
        entry="$(menu_get_item_entry "$menu_name" "$i")"
        IFS='|' read -r label_spec action target <<< "$entry"
        label="$(menu_resolve_label "$label_spec")"
        menu_text+="$((i+1)). $label"$'\n'
    done

    auto_label="$(menu_auto_item_label)"

    if menu_is_top_level; then
        menu_text+="Q. $auto_label"$'\n'
    else
        menu_text+="B. $auto_label"$'\n'
    fi

    pane_set_content "$PANE_MENU_ID" "$menu_text"

    log_info menu "Rendered menu ${menu_name}"
    return 0
}

menu_init() {
    local initial_menu="$1"

    if ! menu_exists "$initial_menu"; then
        log_error menu "Menu init failed, undefined menu ${initial_menu}"
        return 1
    fi

    MENU_STACK=( "$initial_menu" )

    log_notice menu "Initializing menu ${initial_menu}"

    menu_run_on_enter "$initial_menu"
    menu_render "$initial_menu"
}

menu_open() {
    local target_menu="$1"

    if ! menu_exists "$target_menu"; then
        log_warn menu "Attempt to open undefined menu ${target_menu}"
        return 1
    fi

    MENU_STACK+=( "$target_menu" )

    log_info menu "Opening menu ${target_menu}"

    menu_run_on_enter "$target_menu"
    menu_render "$target_menu"
}

menu_go_back() {
    local count
    local leaving_menu
    local new_menu

    count=${#MENU_STACK[@]}
    (( count > 1 )) || return 1

    leaving_menu="${MENU_STACK[count-1]}"

    menu_run_on_back "$leaving_menu"

    unset 'MENU_STACK[count-1]'
    MENU_STACK=( "${MENU_STACK[@]}" )

    new_menu="$(menu_current)"

    log_info menu "Returning from menu ${leaving_menu} to ${new_menu}"

    menu_run_on_enter "$new_menu"
    menu_render "$new_menu"
}

menu_dispatch_configured_item() {

    local entry="$1"
    local label_spec
    local action
    local target

    IFS='|' read -r label_spec action target <<< "$entry"

    case "$action" in

        menu)
            menu_open "$target"
            ;;

        workflow)
            log_info menu "Dispatching workflow ${target}"

            if ! workflow_run "$target"; then
                log_warn menu "Workflow ${target} failed"
                return 1
            fi
            ;;

        *)
            log_error menu "Unknown menu action ${action}"
            return 1
            ;;

    esac
}

select_menu_item() {

    local key="$1"
    local current_menu
    local visible_count
    local index
    local entry

    [[ "$key" =~ ^[1-9]$ ]] || return 1

    current_menu="$(menu_current)"
    visible_count="$(menu_get_visible_real_count "$current_menu")"

    index=$(( key - 1 ))

    if (( index < visible_count )); then

        entry="$(menu_get_item_entry "$current_menu" "$index")"

        menu_dispatch_configured_item "$entry" || return 1

        return 0
    fi

    return 1
}

menu_handle_back_shortcut() {

    if ! menu_is_top_level; then
        log_info menu "Back shortcut used"
        menu_go_back
    fi
}

menu_handle_quit_shortcut() {

    if menu_is_top_level; then
        log_notice menu "Quit shortcut used"
        quit_application
    fi
}

menu_run_on_enter() {
    local menu_name="$1"
    local hook_var="MENU_${menu_name}_ON_ENTER"
    local hook_func="${!hook_var:-}"

    [ -n "$hook_func" ] || return 0

    if ! declare -F "$hook_func" >/dev/null 2>&1; then
        log_warn menu "Missing on-enter hook function ${hook_func} for menu ${menu_name}"
        return 1
    fi

    log_info menu "Running on-enter hook ${hook_func} for menu ${menu_name}"
    "$hook_func" "$menu_name"
}

menu_run_on_back() {
    local menu_name="$1"
    local hook_var="MENU_${menu_name}_ON_BACK"
    local hook_func="${!hook_var:-}"

    [ -n "$hook_func" ] || return 0

    if ! declare -F "$hook_func" >/dev/null 2>&1; then
        log_warn menu "Missing on-back hook function ${hook_func} for menu ${menu_name}"
        return 1
    fi

    log_info menu "Running on-back hook ${hook_func} for menu ${menu_name}"
    "$hook_func" "$menu_name"
}