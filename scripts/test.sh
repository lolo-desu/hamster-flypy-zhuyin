#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/test
swiftc src/FlypyZhuyin.swift tests/main.swift -o work/test/flypy-tests
work/test/flypy-tests
python3 -m unittest discover -s tests -p 'test_*.py' -v
