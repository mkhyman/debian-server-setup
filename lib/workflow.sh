#!/usr/bin/env bash

# Current workflow
CURRENT_WORKFLOW_STEPS=()   # Array of step types
CURRENT_WORKFLOW_TEXTS=()   # Array of messages to display
CURRENT_WORKFLOW_HANDLERS=() # Array of functions to handle responses
CURRENT_WORKFLOW_INDEX=0

# Prompt buffer
PROMPT_BUFFER=""
INPUT_MODE="normal"

# Initialize a workflow
workflow_start() {
    local steps_array="$1[@]"
    local texts_array="$2[@]"
    local handlers_array="$3[@]"

    CURRENT_WORKFLOW_STEPS=("${!steps_array}")
    CURRENT_WORKFLOW_TEXTS=("${!texts_array}")
    CURRENT_WORKFLOW_HANDLERS=("${!handlers_array}")
    CURRENT_WORKFLOW_INDEX=0

    workflow_next_step
}

# Advance to next step
workflow_next_step() {
    if (( CURRENT_WORKFLOW_INDEX >= ${#CURRENT_WORKFLOW_STEPS[@]} )); then
        INPUT_MODE="normal"
        CURRENT_WORKFLOW_STEPS=()
        CURRENT_WORKFLOW_TEXTS=()
        CURRENT_WORKFLOW_HANDLERS=()
        return
    fi

    local step_type="${CURRENT_WORKFLOW_STEPS[CURRENT_WORKFLOW_INDEX]}"
    local message="${CURRENT_WORKFLOW_TEXTS[CURRENT_WORKFLOW_INDEX]}"
    local handler="${CURRENT_WORKFLOW_HANDLERS[CURRENT_WORKFLOW_INDEX]}"
    local allowed="${CURRENT_WORKFLOW_ALLOWED[$CURRENT_WORKFLOW_INDEX]}"  # only for choice

    case "$step_type" in
        "prompt")
            INPUT_MODE="prompt"
            PROMPT_HANDLER="$handler"
            PROMPT_BUFFER=""
            pane_append 3 "$message "
            ;;
        "choice")
            INPUT_MODE="choice"
            CHOICE_HANDLER="$handler"
            CHOICE_ALLOWED="$allowed"
            pane_append 3 "$message ($allowed) "
            ;;
        "display")
            pane_append 3 "$message"
            ((CURRENT_WORKFLOW_INDEX++))
            workflow_next_step
            ;;
    esac
}

# Generic prompt handler for workflows
workflow_choice_handler() {
    local input="$1"
    local allowed="$2"  # string containing valid choices, e.g., "YyNn"

    # If input is not in allowed choices, ignore
    if [[ "$allowed" != *"$input"* ]]; then
        return
    fi

    # Call the step-specific handler
    if [[ -n "${CURRENT_WORKFLOW_HANDLERS[CURRENT_WORKFLOW_INDEX]}" ]]; then
        "${CURRENT_WORKFLOW_HANDLERS[CURRENT_WORKFLOW_INDEX]}" "$input"
    fi

    ((CURRENT_WORKFLOW_INDEX++))
    workflow_next_step
}

# Generic confirmation handler for workflows
workflow_confirmation_handler() {
    local answer="$1"

    if [[ -n "${CURRENT_WORKFLOW_HANDLERS[CURRENT_WORKFLOW_INDEX]}" ]]; then
        "${CURRENT_WORKFLOW_HANDLERS[CURRENT_WORKFLOW_INDEX]}" "$answer"
    fi

    ((CURRENT_WORKFLOW_INDEX++))
    workflow_next_step
}