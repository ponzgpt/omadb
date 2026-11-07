#!/usr/bin/env bash
# The one check: tests (+ reporter lint once it exists). CI and deploy run this.
set -euo pipefail
cd "$(dirname "$0")/.."
run='bin/rails db:test:prepare && bin/rails test'
if ruby -e 'exit(Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("4.0") ? 0 : 1)' 2>/dev/null; then
  bash -c "$run"
else
  scripts/on-hoid "$run"
fi
