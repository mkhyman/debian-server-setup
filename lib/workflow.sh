#!/usr/bin/env bash

###############################################################################
# workflow.sh
#
# Workflow definitions are authored as arrays in workflow files and converted
# once at source time into an internal blob representation.
#
# This mirrors the menu system while avoiding eval and Bash 3 indirect array
# expansion issues.
###############################################################################

workflow_register() {
    local workflow_name="$1"
    shift

    local item
    local blob

    for item in "$@"; do
        workflow_validate_item "$item" || {
            log_error workflow "Failed to register workflow ${workflow_name}"
            return 1
        }
    done

    blob="$(workflow_items_to_blob "$@")"
    printf -v "${workflow_name}_ITEMS_BLOB" '%s' "$blob"

    return 0
}

workflow_items_to_blob() {
    local blob=""
    local item
    local trimmed

    for item in "$@"; do
        # strip CR (handles CRLF files)
        item="${item%$'\r'}"

        # trim whitespace for validation
        trimmed="${item#"${item%%[![:space:]]*}"}"
        trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"

        # skip empty / whitespace-only entries
        [ -n "$trimmed" ] || continue

        if [ -n "$blob" ]; then
            blob+=$'\n'
        fi

        blob+="$item"
    done

    printf '%s' "$blob"
}

workflow_validate_item() {
    local item="$1"
    local step_type
    local step_data
    local extra

    item="${item%$'\r'}"
    [ -n "$item" ] || {
        log_error workflow "Invalid workflow item: empty item"
        return 1
    }

    IFS='|' read -r step_type step_data extra <<< "$item"

    [ -n "${extra:-}" ] && {
        log_error workflow "Invalid workflow item: too many fields: ${item}"
        return 1
    }

    [ -n "${step_type:-}" ] || {
        log_error workflow "Invalid workflow item: missing step type: ${item}"
        return 1
    }

    [ -n "${step_data:-}" ] || {
        log_error workflow "Invalid workflow item: missing step data: ${item}"
        return 1
    }

    case "$step_type" in
        prompt|choice|run)
            ;;
        *)
            log_error workflow "Invalid workflow item: unknown step type '${step_type}': ${item}"
            return 1
            ;;
    esac

    return 0
}

workflow_get_items_blob() {
    local workflow_name="$1"
    local var_name="${workflow_name}_ITEMS_BLOB"

    printf '%s' "${!var_name:-}"
}

workflow_run() {
    local workflow_name="$1"
    local blob
    local step
    local step_type
    local step_data

    blob="$(workflow_get_items_blob "$workflow_name")"

    if [ -z "$blob" ]; then
        log_error workflow "Undefined or empty workflow ${workflow_name}"
        return 1
    fi

    log_notice workflow "Starting workflow ${workflow_name}"

    while IFS= read -r step; do
        [ -n "$step" ] || continue

        IFS='|' read -r step_type step_data <<< "$step"

        log_info workflow "Executing step ${step_type}"

        case "$step_type" in
            prompt)
                workflow_prompt "$step_data"
                ;;

            choice)
                workflow_choice "$step_data"
                ;;

            run)
                if ! "$step_data"; then
                    log_error workflow "Step failed in workflow ${workflow_name}"
                    return 1
                fi
                ;;

            *)
                log_error workflow "Unknown workflow step type ${step_type}"
                return 1
                ;;
        esac
    done <<< "$blob"

    log_notice workflow "Workflow ${workflow_name} completed"

    return 0
}
