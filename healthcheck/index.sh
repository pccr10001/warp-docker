#!/bin/bash

# exit when any command fails
set -e

# get where the script is located
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

bash $DIR/connected-to-warp.sh

