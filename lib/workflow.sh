#!/usr/bin/env bash

###############################################################################
# Workflow Engine
#
# This file implements a simple step-based workflow engine used by the TUI.
#
# Workflows are authored as arrays of pipe-delimited step strings and are
# converted at registration time into an internal blob representation.
#
# Workflow step numbering is 1-based.
#
# Example:
#   workflow_step_jump 5
#
# jumps to the fifth workflow step, not the sixth.
#
# Public workflow API functions do NOT begin with "_".
# Internal workflow engine functions are prefixed with "_".
# Workflow authors must not call underscore-prefixed functions directly.
#
# Supported directives:
#
#   display|pane_id|text
#       Append text to the specified pane. Text may contain newlines.
#
#   set_info|function_name
#       Call the named info render function.
#
#   prompt|pane_id|text|key_name|handler
#       Start a text prompt.
#       Submitted value is always stored in workflow KV using key_name.
#       handler is optional.
#
#   choice|pane_id|text|allowed_keys|key_name|handler
#       Start a one-key choice prompt.
#       Chosen value is always stored in workflow KV using key_name.
#       handler is optional.
#
#   func|function_name
#       Execute a workflow handler function.
#
# Pipe characters ('|') are reserved delimiters inside workflow step strings.
# They cannot appear in directive parameters.
#
# Workflow step states:
#   not_started
#   running
#   paused
#   completed
#   aborted
#
# Workflow handlers must report step results using:
#   workflow_step_completed
#   workflow_step_paused
#   workflow_step_aborted
#   workflow_step_jump <step_number>
#
# Workflow KV helpers:
#   workflow_kv_set key_name value
#   workflow_kv_get key_name
#   workflow_kv_has key_name
#   workflow_kv_unset key_name
#   workflow_kv_clear
#
# Keys must be unique.
# Values are stored as strings and may contain newlines.
#
# Sequential workflow rule:
# A step must not report "completed" until it has finished all work required
# for the workflow to safely proceed to the next step.
###############################################################################

WORKFLOW_ITEM_SEPARATOR=$'\036'

WORKFLOW_ACTIVE=0
WORKFLOW_NAME=""
WORKFLOW_ITEMS_BLOB=""
WORKFLOW_STEP_COUNT=0
WORKFLOW_CURRENT_STEP=1

WORKFLOW_STEP_RESULT=""
WORKFLOW_JUMP_TARGET=""

WORKFLOW_STEP_STATES=()

WORKFLOW_KV_KEYS=()
WORKFLOW_KV_VALUES=()

WORKFLOW_PENDING_KEY_NAME=""
WORKFLOW_PENDING_HANDLER=""

WORKFLOW_PARSED_FIELDS=()

workflow_register() {
    local workflow_name="$1"
    shift

    local item
    local blob

    for item in "$@"; do
        _workflow_validate_item "$item" || {
            log_error workflow "Failed to register workflow ${workflow_name}"
            return 1
        }
    done

    blob="$(_workflow_items_to_blob "$@")"
    printf -v "${workflow_name}_ITEMS_BLOB" '%s' "$blob"

    return 0
}

workflow_start() {
    local workflow_name="$1"
    local blob

    _workflow_reset

    blob="$(_workflow_get_items_blob "$workflow_name")"
    if [ -z "$blob" ]; then
        log_error workflow "Undefined or empty workflow ${workflow_name}"
        return 1
    fi

    WORKFLOW_NAME="$workflow_name"
    WORKFLOW_ITEMS_BLOB="$blob"
    WORKFLOW_STEP_COUNT="$(_workflow_count_steps "$WORKFLOW_ITEMS_BLOB")"
    WORKFLOW_CURRENT_STEP=1
    WORKFLOW_ACTIVE=1

    _workflow_step_state_init "$WORKFLOW_STEP_COUNT"

    log_notice workflow "Starting workflow ${WORKFLOW_NAME}"

    _workflow_continue
}

workflow_step_completed() {
    WORKFLOW_STEP_RESULT="completed"
    WORKFLOW_JUMP_TARGET=""
}

workflow_step_paused() {
    WORKFLOW_STEP_RESULT="paused"
    WORKFLOW_JUMP_TARGET=""
}

workflow_step_aborted() {
    WORKFLOW_STEP_RESULT="aborted"
    WORKFLOW_JUMP_TARGET=""
}

workflow_step_jump() {
    local step_number="$1"

    WORKFLOW_STEP_RESULT="jump"
    WORKFLOW_JUMP_TARGET="$step_number"
}

workflow_prompt() {
    local pane_id="$1"
    local prompt_text="$2"
    local key_name="$3"
    local handler="$4"

    _workflow_validate_key_name "$key_name" || {
        log_error workflow "Invalid workflow prompt key_name '${key_name}'"
        workflow_step_aborted
        return 1
    }

    WORKFLOW_PENDING_KEY_NAME="$key_name"
    WORKFLOW_PENDING_HANDLER="$handler"

    tui_prompt_start "$pane_id" "$prompt_text" "_workflow_prompt_callback"
    workflow_step_paused

    return 0
}

workflow_choice() {
    local pane_id="$1"
    local choice_text="$2"
    local allowed_keys="$3"
    local key_name="$4"
    local handler="$5"

    _workflow_validate_key_name "$key_name" || {
        log_error workflow "Invalid workflow choice key_name '${key_name}'"
        workflow_step_aborted
        return 1
    }

    [ -n "$allowed_keys" ] || {
        log_error workflow "workflow_choice requires allowed_keys"
        workflow_step_aborted
        return 1
    }

    WORKFLOW_PENDING_KEY_NAME="$key_name"
    WORKFLOW_PENDING_HANDLER="$handler"

    tui_choice_start "$pane_id" "$choice_text" "$allowed_keys" "_workflow_choice_callback"
    workflow_step_paused

    return 0
}

workflow_set_info() {
    local handler="$1"

    [ -n "$handler" ] || {
        log_error workflow "workflow_set_info requires a function name"
        workflow_step_aborted
        return 1
    }

    "$handler" || {
        log_error workflow "workflow_set_info failed for '${handler}'"
        workflow_step_aborted
        return 1
    }

    return 0
}

workflow_kv_set() {
    local key_name="$1"
    local value="$2"
    local i
    local count="${#WORKFLOW_KV_KEYS[@]}"

    _workflow_validate_key_name "$key_name" || return 1

    for (( i=0; i<count; i++ )); do
        if [ "${WORKFLOW_KV_KEYS[$i]}" = "$key_name" ]; then
            WORKFLOW_KV_VALUES[$i]="$value"
            return 0
        fi
    done

    WORKFLOW_KV_KEYS[$count]="$key_name"
    WORKFLOW_KV_VALUES[$count]="$value"

    return 0
}

workflow_kv_get() {
    local key_name="$1"
    local i
    local count="${#WORKFLOW_KV_KEYS[@]}"

    for (( i=0; i<count; i++ )); do
        if [ "${WORKFLOW_KV_KEYS[$i]}" = "$key_name" ]; then
            printf '%s' "${WORKFLOW_KV_VALUES[$i]}"
            return 0
        fi
    done

    return 1
}

workflow_kv_has() {
    local key_name="$1"
    local i
    local count="${#WORKFLOW_KV_KEYS[@]}"

    for (( i=0; i<count; i++ )); do
        if [ "${WORKFLOW_KV_KEYS[$i]}" = "$key_name" ]; then
            return 0
        fi
    done

    return 1
}

workflow_kv_unset() {
    local key_name="$1"
    local i
    local j
    local count="${#WORKFLOW_KV_KEYS[@]}"

    for (( i=0; i<count; i++ )); do
        if [ "${WORKFLOW_KV_KEYS[$i]}" = "$key_name" ]; then
            for (( j=i; j<count-1; j++ )); do
                WORKFLOW_KV_KEYS[$j]="${WORKFLOW_KV_KEYS[$((j+1))]}"
                WORKFLOW_KV_VALUES[$j]="${WORKFLOW_KV_VALUES[$((j+1))]}"
            done

            unset 'WORKFLOW_KV_KEYS[$((count-1))]'
            unset 'WORKFLOW_KV_VALUES[$((count-1))]'

            return 0
        fi
    done

    return 1
}

workflow_kv_clear() {
    WORKFLOW_KV_KEYS=()
    WORKFLOW_KV_VALUES=()
}

_workflow_reset() {
    WORKFLOW_ACTIVE=0
    WORKFLOW_NAME=""
    WORKFLOW_ITEMS_BLOB=""
    WORKFLOW_STEP_COUNT=0
    WORKFLOW_CURRENT_STEP=1

    WORKFLOW_STEP_RESULT=""
    WORKFLOW_JUMP_TARGET=""

    WORKFLOW_STEP_STATES=()

    workflow_kv_clear

    WORKFLOW_PENDING_KEY_NAME=""
    WORKFLOW_PENDING_HANDLER=""

    WORKFLOW_PARSED_FIELDS=()
}

_workflow_continue() {
    local step
    local step_type

    while [ "$WORKFLOW_ACTIVE" -eq 1 ]; do
        if [ -z "$WORKFLOW_STEP_RESULT" ]; then
            _workflow_step_state_set "$WORKFLOW_CURRENT_STEP" "running" || {
                log_error workflow "Invalid current step ${WORKFLOW_CURRENT_STEP}"
                _workflow_abort
                return 1
            }

            step="$(_workflow_get_step "$WORKFLOW_ITEMS_BLOB" "$WORKFLOW_CURRENT_STEP")"
            if [ -z "$step" ]; then
                log_error workflow "Missing step ${WORKFLOW_CURRENT_STEP} in workflow ${WORKFLOW_NAME}"
                _workflow_step_state_set "$WORKFLOW_CURRENT_STEP" "aborted"
                _workflow_abort
                return 1
            fi

            _workflow_parse_step "$step" || {
                log_error workflow "Failed to parse step ${WORKFLOW_CURRENT_STEP} in workflow ${WORKFLOW_NAME}"
                _workflow_step_state_set "$WORKFLOW_CURRENT_STEP" "aborted"
                _workflow_abort
                return 1
            }

            step_type="${WORKFLOW_PARSED_FIELDS[0]}"

            log_info workflow "Executing step ${WORKFLOW_CURRENT_STEP} (${step_type})"

            case "$step_type" in
                display)
                    pane_append "${WORKFLOW_PARSED_FIELDS[1]}" "${WORKFLOW_PARSED_FIELDS[2]}"
                    workflow_step_completed
                    ;;

                set_info)
                    workflow_set_info "${WORKFLOW_PARSED_FIELDS[1]}"
                    [ -n "$WORKFLOW_STEP_RESULT" ] || workflow_step_completed
                    ;;

                prompt)
                    workflow_prompt \
                        "${WORKFLOW_PARSED_FIELDS[1]}" \
                        "${WORKFLOW_PARSED_FIELDS[2]}" \
                        "${WORKFLOW_PARSED_FIELDS[3]}" \
                        "${WORKFLOW_PARSED_FIELDS[4]}"
                    ;;

                choice)
                    workflow_choice \
                        "${WORKFLOW_PARSED_FIELDS[1]}" \
                        "${WORKFLOW_PARSED_FIELDS[2]}" \
                        "${WORKFLOW_PARSED_FIELDS[3]}" \
                        "${WORKFLOW_PARSED_FIELDS[4]}" \
                        "${WORKFLOW_PARSED_FIELDS[5]}"
                    ;;

                func)
                    "${WORKFLOW_PARSED_FIELDS[1]}"
                    ;;

                *)
                    log_error workflow "Unknown workflow step type ${step_type}"
                    workflow_step_aborted
                    ;;
            esac
        fi

        case "$WORKFLOW_STEP_RESULT" in
            completed)
                _workflow_step_state_set "$WORKFLOW_CURRENT_STEP" "completed"
                _workflow_clear_step_result
                _workflow_clear_pending_input
                WORKFLOW_CURRENT_STEP=$((WORKFLOW_CURRENT_STEP + 1))

                if [ "$WORKFLOW_CURRENT_STEP" -gt "$WORKFLOW_STEP_COUNT" ]; then
                    _workflow_complete
                    return 0
                fi
                ;;

            paused)
                _workflow_step_state_set "$WORKFLOW_CURRENT_STEP" "paused"
                return 0
                ;;

            aborted)
                _workflow_step_state_set "$WORKFLOW_CURRENT_STEP" "aborted"
                _workflow_abort
                return 1
                ;;

            jump)
                if ! _workflow_validate_jump_target "$WORKFLOW_JUMP_TARGET"; then
                    log_error workflow "Invalid jump target ${WORKFLOW_JUMP_TARGET}"
                    _workflow_step_state_set "$WORKFLOW_CURRENT_STEP" "aborted"
                    _workflow_abort
                    return 1
                fi

                _workflow_step_state_set "$WORKFLOW_CURRENT_STEP" "completed"
                WORKFLOW_CURRENT_STEP="$WORKFLOW_JUMP_TARGET"
                _workflow_clear_step_result
                _workflow_clear_pending_input
                ;;

            "")
                log_error workflow "Step ${WORKFLOW_CURRENT_STEP} did not report a result in workflow ${WORKFLOW_NAME}"
                _workflow_step_state_set "$WORKFLOW_CURRENT_STEP" "aborted"
                _workflow_abort
                return 1
                ;;

            *)
                log_error workflow "Unknown workflow step result '${WORKFLOW_STEP_RESULT}'"
                _workflow_step_state_set "$WORKFLOW_CURRENT_STEP" "aborted"
                _workflow_abort
                return 1
                ;;
        esac
    done

    return 0
}

_workflow_abort() {
    log_error workflow "Workflow ${WORKFLOW_NAME} aborted"
    _workflow_reset
}

_workflow_complete() {
    log_notice workflow "Workflow ${WORKFLOW_NAME} completed"
    _workflow_reset
}

_workflow_prompt_callback() {
    local value="$1"

    _workflow_step_state_set "$WORKFLOW_CURRENT_STEP" "running" || {
        log_error workflow "Invalid current step during prompt callback"
        _workflow_abort
        return 1
    }

    _workflow_clear_step_result

    workflow_kv_set "$WORKFLOW_PENDING_KEY_NAME" "$value" || {
        log_error workflow "Failed to store prompt result in key '${WORKFLOW_PENDING_KEY_NAME}'"
        workflow_step_aborted
        _workflow_continue
        return 1
    }

    if [ -n "$WORKFLOW_PENDING_HANDLER" ]; then
        "${WORKFLOW_PENDING_HANDLER}" "$value"
    else
        workflow_step_completed
    fi

    _workflow_continue
}

_workflow_choice_callback() {
    local value="$1"

    _workflow_step_state_set "$WORKFLOW_CURRENT_STEP" "running" || {
        log_error workflow "Invalid current step during choice callback"
        _workflow_abort
        return 1
    }

    _workflow_clear_step_result

    workflow_kv_set "$WORKFLOW_PENDING_KEY_NAME" "$value" || {
        log_error workflow "Failed to store choice result in key '${WORKFLOW_PENDING_KEY_NAME}'"
        workflow_step_aborted
        _workflow_continue
        return 1
    }

    if [ -n "$WORKFLOW_PENDING_HANDLER" ]; then
        "${WORKFLOW_PENDING_HANDLER}" "$value"
    else
        workflow_step_completed
    fi

    _workflow_continue
}

_workflow_items_to_blob() {
    local blob=""
    local item
    local trimmed

    for item in "$@"; do
        item="${item%$'\r'}"

        trimmed="${item#"${item%%[![:space:]]*}"}"
        trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"

        [ -n "$trimmed" ] || continue

        if [ -n "$blob" ]; then
            blob+="$WORKFLOW_ITEM_SEPARATOR"
        fi

        blob+="$item"
    done

    printf '%s' "$blob"
}

_workflow_validate_item() {
    local item="$1"
    local step_type
    local field_count

    item="${item%$'\r'}"
    [ -n "$item" ] || {
        log_error workflow "Invalid workflow item: empty item"
        return 1
    }

    _workflow_parse_step "$item" || {
        log_error workflow "Invalid workflow item: could not parse: ${item}"
        return 1
    }

    field_count="${#WORKFLOW_PARSED_FIELDS[@]}"
    step_type="${WORKFLOW_PARSED_FIELDS[0]}"

    [ -n "$step_type" ] || {
        log_error workflow "Invalid workflow item: missing step type"
        return 1
    }

    case "$step_type" in
        display)
            [ "$field_count" -eq 3 ] || {
                log_error workflow "Invalid display step: expected 3 fields"
                return 1
            }

            [ -n "${WORKFLOW_PARSED_FIELDS[1]}" ] || {
                log_error workflow "Invalid display step: missing pane_id"
                return 1
            }
            ;;

        set_info)
            [ "$field_count" -eq 2 ] || {
                log_error workflow "Invalid set_info step: expected 2 fields"
                return 1
            }

            [ -n "${WORKFLOW_PARSED_FIELDS[1]}" ] || {
                log_error workflow "Invalid set_info step: missing function_name"
                return 1
            }
            ;;

        prompt)
            [ "$field_count" -eq 5 ] || {
                log_error workflow "Invalid prompt step: expected 5 fields"
                return 1
            }

            [ -n "${WORKFLOW_PARSED_FIELDS[1]}" ] || {
                log_error workflow "Invalid prompt step: missing pane_id"
                return 1
            }

            [ -n "${WORKFLOW_PARSED_FIELDS[3]}" ] || {
                log_error workflow "Invalid prompt step: missing key_name"
                return 1
            }

            _workflow_validate_key_name "${WORKFLOW_PARSED_FIELDS[3]}" || {
                log_error workflow "Invalid prompt step: invalid key_name '${WORKFLOW_PARSED_FIELDS[3]}'"
                return 1
            }
            ;;

        choice)
            [ "$field_count" -eq 6 ] || {
                log_error workflow "Invalid choice step: expected 6 fields"
                return 1
            }

            [ -n "${WORKFLOW_PARSED_FIELDS[1]}" ] || {
                log_error workflow "Invalid choice step: missing pane_id"
                return 1
            }

            [ -n "${WORKFLOW_PARSED_FIELDS[3]}" ] || {
                log_error workflow "Invalid choice step: missing allowed_keys"
                return 1
            }

            [ -n "${WORKFLOW_PARSED_FIELDS[4]}" ] || {
                log_error workflow "Invalid choice step: missing key_name"
                return 1
            }

            _workflow_validate_key_name "${WORKFLOW_PARSED_FIELDS[4]}" || {
                log_error workflow "Invalid choice step: invalid key_name '${WORKFLOW_PARSED_FIELDS[4]}'"
                return 1
            }
            ;;

        func)
            [ "$field_count" -eq 2 ] || {
                log_error workflow "Invalid func step: expected 2 fields"
                return 1
            }

            [ -n "${WORKFLOW_PARSED_FIELDS[1]}" ] || {
                log_error workflow "Invalid func step: missing function_name"
                return 1
            }
            ;;

        *)
            log_error workflow "Invalid workflow item: unknown step type '${step_type}'"
            return 1
            ;;
    esac

    return 0
}

_workflow_get_items_blob() {
    local workflow_name="$1"
    local var_name="${workflow_name}_ITEMS_BLOB"

    printf '%s' "${!var_name:-}"
}

_workflow_count_steps() {
    local blob="$1"
    local rest
    local count=0

    [ -n "$blob" ] || {
        printf '0'
        return 0
    }

    rest="${blob}${WORKFLOW_ITEM_SEPARATOR}"

    while [[ "$rest" == *"$WORKFLOW_ITEM_SEPARATOR"* ]]; do
        count=$((count + 1))
        rest="${rest#*"$WORKFLOW_ITEM_SEPARATOR"}"
    done

    printf '%s' "$count"
}

_workflow_get_step() {
    local blob="$1"
    local step_number="$2"
    local rest
    local item
    local current=1

    [ -n "$blob" ] || return 1

    rest="${blob}${WORKFLOW_ITEM_SEPARATOR}"

    while [[ "$rest" == *"$WORKFLOW_ITEM_SEPARATOR"* ]]; do
        item="${rest%%"$WORKFLOW_ITEM_SEPARATOR"*}"

        if [ "$current" -eq "$step_number" ]; then
            printf '%s' "$item"
            return 0
        fi

        rest="${rest#*"$WORKFLOW_ITEM_SEPARATOR"}"
        current=$((current + 1))
    done

    return 1
}

_workflow_parse_step() {
    local step="$1"
    local rest="$step"
    local field
    local index=0

    WORKFLOW_PARSED_FIELDS=()

    while :; do
        if [[ "$rest" == *"|"* ]]; then
            field="${rest%%|*}"
            WORKFLOW_PARSED_FIELDS[$index]="$field"
            rest="${rest#*|}"
            index=$((index + 1))
            continue
        fi

        WORKFLOW_PARSED_FIELDS[$index]="$rest"
        break
    done

    return 0
}

_workflow_step_state_init() {
    local step_count="$1"
    local i

    WORKFLOW_STEP_STATES=()

    for (( i=0; i<step_count; i++ )); do
        WORKFLOW_STEP_STATES[$i]="not_started"
    done
}

_workflow_step_state_set() {
    local step_number="$1"
    local state="$2"
    local index

    index="$(_workflow_step_number_to_index "$step_number")" || return 1
    WORKFLOW_STEP_STATES[$index]="$state"
}

_workflow_step_state_get() {
    local step_number="$1"
    local index

    index="$(_workflow_step_number_to_index "$step_number")" || return 1
    printf '%s' "${WORKFLOW_STEP_STATES[$index]}"
}

_workflow_step_number_to_index() {
    local step_number="$1"

    [ -n "$step_number" ] || return 1
    [ "$step_number" -ge 1 ] 2>/dev/null || return 1

    printf '%s' "$((step_number - 1))"
}

_workflow_step_index_to_number() {
    local step_index="$1"

    [ -n "$step_index" ] || return 1
    [ "$step_index" -ge 0 ] 2>/dev/null || return 1

    printf '%s' "$((step_index + 1))"
}

_workflow_validate_jump_target() {
    local step_number="$1"

    [ -n "$step_number" ] || return 1
    [ "$step_number" -ge 1 ] 2>/dev/null || return 1
    [ "$step_number" -le "$WORKFLOW_STEP_COUNT" ] 2>/dev/null || return 1

    return 0
}

_workflow_validate_key_name() {
    local key_name="$1"

    [[ "$key_name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
}

_workflow_clear_step_result() {
    WORKFLOW_STEP_RESULT=""
    WORKFLOW_JUMP_TARGET=""
}

_workflow_clear_pending_input() {
    WORKFLOW_PENDING_KEY_NAME=""
    WORKFLOW_PENDING_HANDLER=""
}