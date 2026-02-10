#!/bin/sh
###############################################################################
# bootstrap_and_load.sh – Legacy entrypoint (kept for backwards compatibility)
# The main pipeline now uses run_pipeline.sh.
# This script is a thin wrapper that delegates to run_pipeline.sh.
###############################################################################

exec sh /scripts/run_pipeline.sh "$@"
