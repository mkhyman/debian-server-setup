#!/usr/bin/env bash

MENU_PANE_ID=1
MENU_STACK=()
MENU_STRICT_HANDLERS=1

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
    [[ -n "${!title_var}" ]]
}

menu_get_title() {
    local menu_name="$1"
    local title_var="MENU_${menu_name}_TITLE"
    printf '%s' "${!title_var}"
}

menu_get_items() {
    local menu_name="$1"
    local var_name="MENU_${menu_name}_ITEMS[@]"
    printf '%s\n' "${!var_name}"
}

menu_get_item_count() {
    local menu_name="$1"
    local var_name="MENU_${menu_name}_ITEMS[@]"
    local items=( "${!var_name}" )
    printf '%s' "${#items[@]}"
}

menu_real_item_limit() {
    printf '9'
}

menu_get_visible_real_count() {
    local menu_name="$1"
    local count
    local limit

    count="$(menu_get_item_count "$menu_name")"
    limit="$(menu_real_item_limit)"

    if (( count > limit )); then
        count="$limit"
    fi

    printf '%s' "$count"
}

menu_get_item_entry() {
    local menu_name="$1"
    local index="$2"
    local var_name="MENU_${menu_name}_ITEMS[@]"
    local items=( "${!var_name}" )

    printf '%s' "${items[index]}"
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

    if ! menu_exists "$menu_name"; then
        log_error menu "Attempt to render undefined menu ${menu_name}"
        return 1
    fi

    title="$(menu_get_title "$menu_name")"
    visible_count="$(menu_get_visible_real_count "$menu_name")"

    pane_clear "$MENU_PANE_ID"

    pane_append "$MENU_PANE_ID" "$title"
    pane_append "$MENU_PANE_ID" "--------------------"

    for ((i=0; i<visible_count; i++)); do

        entry="$(menu_get_item_entry "$menu_name" "$i")"

        IFS='|' read -r label_spec action target <<< "$entry"

        label="$(menu_resolve_label "$label_spec")"

        pane_append "$MENU_PANE_ID" "$((i+1)). $label"

    done

    auto_label="$(menu_auto_item_label)"

    if menu_is_top_level; then
        pane_append "$MENU_PANE_ID" "Q. $auto_label"
    else
        pane_append "$MENU_PANE_ID" "B. $auto_label"
    fi

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

    menu_render "$target_menu"
}

menu_go_back() {

    local count
    local leaving_menu
    local new_menu

    count=${#MENU_STACK[@]}

    (( count > 1 )) || return 1

    leaving_menu="${MENU_STACK[count-1]}"

    unset 'MENU_STACK[count-1]'
    MENU_STACK=( "${MENU_STACK[@]}" )

    new_menu="$(menu_current)"

    log_info menu "Returning from menu ${leaving_menu} to ${new_menu}"

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