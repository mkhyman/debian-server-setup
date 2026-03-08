#!/bin/bash
set -euo pipefail

SCRIPTS_DIR="./scripts"
MENU_FILE="./menu.csv"

# Make all .sh files executable
chmod +x "$SCRIPTS_DIR"/*.sh 2>/dev/null || true

# Check if menu file exists
if [[ ! -f "$MENU_FILE" ]]; then
  echo "Menu file $MENU_FILE not found."
  exit 1
fi

# Read menu into arrays (preserve blank lines)
scripts=()
display_names=()

while IFS= read -r line || [[ -n "$line" ]]; do
  # If line is empty, store empty values for spacing
  if [[ -z "$line" ]]; then
    scripts+=("")
    display_names+=("")
    continue
  fi

  # Extract filename and displayname
  if [[ $line =~ \"([^\"]+)\"[[:space:]]+\"([^\"]+)\" ]]; then
    script_name="${BASH_REMATCH[1]}"
    display_name="${BASH_REMATCH[2]}"
    script_path="$SCRIPTS_DIR/$script_name"

    # Confirm script exists
    if [[ ! -f "$script_path" ]]; then
      echo "Script not found: $script_path"
      exit 1
    fi

    scripts+=("$script_name")
    display_names+=("$display_name")
  fi
done < "$MENU_FILE"

# Check if any entries found
if [ ${#scripts[@]} -eq 0 ]; then
  echo "No valid entries found in $MENU_FILE"
  exit 1
fi

# Display menu
echo "=== Scripts Menu ==="
for i in "${!display_names[@]}"; do
  if [[ -z "${display_names[$i]}" ]]; then
    echo  # Print blank line
  else
    echo "$((i+1))) ${display_names[$i]}"
  fi
done
echo "x) Exit"

# Get choice
read -p "Choose an option: " choice

# Handle exit
if [ "$choice" == "x" ]; then
  echo "Exiting."
  exit 0
fi

# Validate and run
if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#scripts[@]}" ]; then
  script_name="${scripts[$((choice-1))]}"
  display_name="${display_names[$((choice-1))]}"

  # Skip if blank line
  if [[ -z "$script_name" ]]; then
    echo "Invalid choice."
    exit 1
  fi

  echo "Running $display_name..."
  "$SCRIPTS_DIR/$script_name"
else
  echo "Invalid choice."
  exit 1
fi   