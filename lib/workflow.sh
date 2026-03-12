#!/usr/bin/env bash

workflow_run() {

    local workflow_name="$1"
    local var="WORKFLOW_${workflow_name}[@]"
    local steps=( "${!var}" )
    local step
    local step_type
    local step_data

    log_notice workflow "Starting workflow ${workflow_name}"

    for step in "${steps[@]}"; do

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

    done

    log_notice workflow "Workflow ${workflow_name} completed"

    return 0
}