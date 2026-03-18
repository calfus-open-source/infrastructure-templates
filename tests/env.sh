#!/bin/bash
# Environment setup for tests
# Ensures proper path context when running tests from root or tests/ directory

ROOT_DIR="$(cd "$(dirname \"${BASH_SOURCE[0]}\")/.." && pwd)"
export ROOT_DIR
export SCRIPTS="$ROOT_DIR/scripts"
