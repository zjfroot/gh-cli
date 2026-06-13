#!/bin/bash
# Runs the go_test binary from the git/ subdirectory of runfiles,
# so that ./fixtures/simple.git resolves correctly.
#
# Bazel's go_test CWD = _main/ (runfiles root)
# Data files live at _main/git/fixtures/
# Test code expects ./fixtures/simple.git
# Solution: cd to _main/git/ before running the test.

set -e

cd git
exec ./git_test_bin_/git_test_bin "$@"
