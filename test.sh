#!/bin/bash
set -euo pipefail
src="$(cd "$(dirname "$0")" && pwd)"
build="$src/build/tests"
mkdir -p "$build"
for suite in Tests RoutingTests; do
    swiftc "$src/Sources/Core.swift" "$src/Sources/$suite.swift" -o "$build/$suite" -framework SystemConfiguration
    "$build/$suite" "$@"
done
swiftc -D CONTROLS_TESTING "$src/Sources/Core.swift" "$src/Sources/Controls.swift" "$src/Sources/ControlsTests.swift" -o "$build/ControlsTests" -framework SystemConfiguration -framework Cocoa
"$build/ControlsTests"
