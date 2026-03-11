#!/usr/bin/env bash

#################################
# TEST WORKFLOW DATA
#################################

TEST_WORKFLOW_USERNAME=""
TEST_WORKFLOW_COLOUR=""

#################################
# TEST WORKFLOW STEP DEFINITIONS
#################################

TEST_WORKFLOW_STEPS=(
    "prompt"
    "prompt"
    "display"
    "display"
    "choice"
    "display"
    "display"
)

TEST_WORKFLOW_TEXTS=(
    "Enter username: "
    "Enter favourite colour: "
    ""
    ""
    "Would u like to delete user? (y/n)"
    ""
    ""
)

TEST_WORKFLOW_HANDLERS=(
    "test_workflow_set_username"
    "test_workflow_set_colour"
    "test_workflow_display_selected_username"
    "test_workflow_check_user_exists"
    "test_workflow_confirm_delete"
    "test_workflow_display_deleted"
    "test_workflow_display_summary"
)

TEST_WORKFLOW_ALLOWED=(
    ""
    ""
    ""
    ""
    "yn"
    ""
    ""
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
        pane_append 3 "user not found"
        workflow_end
    fi
}

test_workflow_confirm_delete() {
    local answer="$1"

    case "$answer" in
        y)
            # continue to next step
            ;;
        n)
            pane_append 3 "user not deleted"
            workflow_end
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

    workflow_start \
        TEST_WORKFLOW_STEPS \
        TEST_WORKFLOW_TEXTS \
        TEST_WORKFLOW_HANDLERS \
        TEST_WORKFLOW_ALLOWED
}