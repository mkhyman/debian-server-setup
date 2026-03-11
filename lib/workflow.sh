#!/usr/bin/env bash

#################################
# WORKFLOW STATE
#################################

CURRENT_WORKFLOW=()
CURRENT_WORKFLOW_INDEX=0
WORKFLOW_ACTIVE=0

#################################
# CLEAR WORKFLOW STATE
#################################

workflow_clear() {
    CURRENT_WORKFLOW=()
    CURRENT_WORKFLOW_INDEX=0
    WORKFLOW_ACTIVE=0
}

#################################
# START WORKFLOW
#################################

workflow_start() {
    local workflow_array="$1[@]"

    workflow_clear

    CURRENT_WORKFLOW=("${!workflow_array}")
    CURRENT_WORKFLOW_INDEX=0
    WORKFLOW_ACTIVE=1

    workflow_next_step
}

#################################
# MOVE TO NEXT STEP
#################################

workflow_next_step() {
    local step
    local step_type
    local step_text
    local step_handler
    local step_allowed

    if (( WORKFLOW_ACTIVE == 0 )); then
        return
    fi

    if (( CURRENT_WORKFLOW_INDEX >= ${#CURRENT_WORKFLOW[@]} )); then
        workflow_clear
        return
    fi

    step="${CURRENT_WORKFLOW[CURRENT_WORKFLOW_INDEX]}"

    IFS='|' read -r step_type step_text step_handler step_allowed <<< "$step"

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
# GENERIC PROMPT RESULT HANDLER
#################################

workflow_prompt_result() {
    local value="$1"
    local step
    local step_type
    local step_text
    local step_handler
    local step_allowed

    if (( WORKFLOW_ACTIVE == 0 )); then
        return
    fi

    step="${CURRENT_WORKFLOW[CURRENT_WORKFLOW_INDEX]}"
    IFS='|' read -r step_type step_text step_handler step_allowed <<< "$step"

    if [[ -n "$step_handler" ]]; then
        "$step_handler" "$value"
    fi

    if (( WORKFLOW_ACTIVE == 0 )); then
        return
    fi

    (( CURRENT_WORKFLOW_INDEX++ ))
    workflow_next_step
}

#################################
# GENERIC CHOICE RESULT HANDLER
#################################

workflow_choice_result() {
    local value="$1"
    local step
    local step_type
    local step_text
    local step_handler
    local step_allowed

    if (( WORKFLOW_ACTIVE == 0 )); then
        return
    fi

    step="${CURRENT_WORKFLOW[CURRENT_WORKFLOW_INDEX]}"
    IFS='|' read -r step_type step_text step_handler step_allowed <<< "$step"

    if [[ -n "$step_handler" ]]; then
        "$step_handler" "$value"
    fi

    if (( WORKFLOW_ACTIVE == 0 )); then
        return
    fi

    (( CURRENT_WORKFLOW_INDEX++ ))
    workflow_next_step
}

#################################
# OPTIONAL HELPER
#################################

workflow_abort() {
    local message="$1"

    if [[ -n "$message" ]]; then
        pane_append 3 "$message"
    fi

    workflow_clear
}