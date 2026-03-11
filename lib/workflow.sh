#!/usr/bin/env bash

#################################
# WORKFLOW STATE
#################################

CURRENT_WORKFLOW_STEPS=()
CURRENT_WORKFLOW_TEXTS=()
CURRENT_WORKFLOW_HANDLERS=()
CURRENT_WORKFLOW_ALLOWED=()
CURRENT_WORKFLOW_INDEX=0
WORKFLOW_ACTIVE=0

#################################
# START / END
#################################

workflow_start() {
    local steps_array="$1[@]"
    local texts_array="$2[@]"
    local handlers_array="$3[@]"
    local allowed_array="$4[@]"

    CURRENT_WORKFLOW_STEPS=("${!steps_array}")
    CURRENT_WORKFLOW_TEXTS=("${!texts_array}")
    CURRENT_WORKFLOW_HANDLERS=("${!handlers_array}")
    CURRENT_WORKFLOW_ALLOWED=("${!allowed_array}")
    CURRENT_WORKFLOW_INDEX=0
    WORKFLOW_ACTIVE=1

    workflow_next_step
}

workflow_clear() {
    CURRENT_WORKFLOW_STEPS=()
    CURRENT_WORKFLOW_TEXTS=()
    CURRENT_WORKFLOW_HANDLERS=()
    CURRENT_WORKFLOW_ALLOWED=()
    CURRENT_WORKFLOW_INDEX=0
    WORKFLOW_ACTIVE=0
}

#################################
# ADVANCE TO NEXT STEP
#################################

workflow_next_step() {
    local step_type
    local step_text
    local step_handler
    local step_allowed

    if (( WORKFLOW_ACTIVE == 0 )); then
        return
    fi

    if (( CURRENT_WORKFLOW_INDEX >= ${#CURRENT_WORKFLOW_STEPS[@]} )); then
        workflow_clear
        return
    fi

    step_type="${CURRENT_WORKFLOW_STEPS[CURRENT_WORKFLOW_INDEX]}"
    step_text="${CURRENT_WORKFLOW_TEXTS[CURRENT_WORKFLOW_INDEX]}"
    step_handler="${CURRENT_WORKFLOW_HANDLERS[CURRENT_WORKFLOW_INDEX]}"
    step_allowed="${CURRENT_WORKFLOW_ALLOWED[CURRENT_WORKFLOW_INDEX]}"

    case "$step_type" in
        prompt)
            start_prompt "$step_text" "workflow_prompt_result"
            ;;

        choice)
            start_choice "$step_text" "$step_allowed" "workflow_choice_result"
            ;;

        display)
            if [[ -n "$step_text" ]]; then
                pane_append 3 "$step_text"
            fi

            if [[ -n "$step_handler" ]]; then
                "$step_handler"
            fi

            if (( WORKFLOW_ACTIVE == 0 )); then
                return
            fi

            (( CURRENT_WORKFLOW_INDEX++ ))
            workflow_next_step
            ;;

        *)
            pane_append 3 "Workflow error: unknown step type '$step_type'"
            workflow_clear
            ;;
    esac
}

#################################
# RESULT HANDLERS CALLED BY
# start_prompt / start_choice
#################################

workflow_prompt_result() {
    local value="$1"
    local step_handler

    if (( WORKFLOW_ACTIVE == 0 )); then
        return
    fi

    step_handler="${CURRENT_WORKFLOW_HANDLERS[CURRENT_WORKFLOW_INDEX]}"

    if [[ -n "$step_handler" ]]; then
        "$step_handler" "$value"
    fi

    if (( WORKFLOW_ACTIVE == 0 )); then
        return
    fi

    ((CURRENT_WORKFLOW_INDEX++))
    workflow_next_step
}

workflow_choice_result() {
    local value="$1"
    local step_handler

    if (( WORKFLOW_ACTIVE == 0 )); then
        return
    fi

    step_handler="${CURRENT_WORKFLOW_HANDLERS[CURRENT_WORKFLOW_INDEX]}"

    if [[ -n "$step_handler" ]]; then
        "$step_handler" "$value"
    fi

    if (( WORKFLOW_ACTIVE == 0 )); then
        return
    fi

    ((CURRENT_WORKFLOW_INDEX++))
    workflow_next_step
}

# useful for workflows to abort with a message
workflow_abort() {
    pane_append 3 "$1"
    workflow_clear
}