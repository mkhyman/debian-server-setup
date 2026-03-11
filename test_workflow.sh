#!/usr/bin/env bash

#################################
# TEST WORKFLOW STATE
#################################

TEST_WORKFLOW_USERNAME=""
TEST_WORKFLOW_COLOUR=""

#################################
# TEST WORKFLOW DEFINITION
#
# Format:
#   type|text|handler|allowed
#
# type:
#   prompt
#   choice
#   display
#################################

TEST_WORKFLOW=(
    "prompt|Enter username: |test_workflow_set_username|"
    "prompt|Enter favourite colour: |test_workflow_set_colour|"
    "display||test_workflow_display_selected_username|"
    "display||test_workflow_check_user_exists|"
    "choice|Would u like to delete user? (y/n)|test_workflow_confirm_delete|yn"
    "display||test_workflow_display_deleted|"
    "display||test_workflow_display_summary|"
)

#################################
# STEP HANDLERS
#################################

test_workflow_set_username() {
    TEST_WORKFLOW_USERNAME="$1"
}

test_workflow_set_colour() {
    TEST_WORKFLOW_COLOUR="$1"
}

test_workflow_display_selected_username() {
    pane_append 3 "you selected ${TEST_WORKFLOW_USERNAME}"
}

test_workflow_check_user_exists() {
    if ! id "$TEST_WORKFLOW_USERNAME" >/dev/null 2>&1; then
        workflow_abort "user not found"
    fi
}

test_workflow_confirm_delete() {
    local answer="$1"

    case "$answer" in
        y)
            ;;
        n)
            workflow_abort "user not deleted"
            ;;
    esac
}

test_workflow_display_deleted() {
    pane_append 3 "user deleted"
}

test_workflow_display_summary() {
    pane_append 3 "username: ${TEST_WORKFLOW_USERNAME}"
    pane_append 3 "colour: ${TEST_WORKFLOW_COLOUR}"
}

#################################
# START FUNCTION
#################################

start_test_workflow() {
    TEST_WORKFLOW_USERNAME=""
    TEST_WORKFLOW_COLOUR=""

    workflow_start TEST_WORKFLOW
}