#!/bin/bash
set -euo pipefail

# update apt package list - what packages and version are available - should run thos before installing/updating anything)
sudo apt-get update

# upgrade all installed packages
sudo apt-get upgrade

# perform upgrades involving changing dependencies, adding or removing new packages as necessary, not covered by previous command)
sudo apt-get dist-upgrade

# remove packages that are no longer needed)
sudo apt-get autoremove