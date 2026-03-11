#!/usr/bin/env bash

source ./libs/constants.sh
source ./libs/panes.sh


# Terminal setup
#trap "stty sane; tput cnorm; clear; exit" INT TERM
trap "stty sane; tput cnorm; exit" INT TERM
tput civis

clear_overview_pane
clear_menu_pane
clear_info_pane
clear_action_pane