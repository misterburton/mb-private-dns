#!/bin/bash
set -euo pipefail
src="$(cd "$(dirname "$0")" && pwd)"
build="$src/build/tests"
mkdir -p "$build"
for suite in Tests RoutingTests NetworkTests ReadinessTests; do
    swiftc "$src/Sources/Core.swift" "$src/Sources/$suite.swift" -o "$build/$suite" -framework SystemConfiguration
    "$build/$suite" "$@"
done
swiftc -D CONTROLS_TESTING "$src/Sources/Core.swift" "$src/Sources/AppIcon.swift" "$src/Sources/Controls.swift" "$src/Sources/Updates.swift" "$src/Sources/ControlsTests.swift" -o "$build/ControlsTests" -framework SystemConfiguration -framework Cocoa
"$build/ControlsTests"
swiftc "$src/Sources/Core.swift" "$src/Sources/Updates.swift" "$src/Sources/UpdateTests.swift" -o "$build/UpdateTests" -framework SystemConfiguration
"$build/UpdateTests" "$@"
badge_app="$build/BadgeTests.app"
mkdir -p "$badge_app/Contents/MacOS" "$badge_app/Contents/Resources"
cp -R "$src/Resources/Icon/StatusBadges" "$badge_app/Contents/Resources/"
swiftc -D CONTROLS_TESTING "$src/Sources/Core.swift" "$src/Sources/AppIcon.swift" "$src/Sources/Controls.swift" "$src/Sources/Updates.swift" "$src/Sources/BadgeTests.swift" -o "$badge_app/Contents/MacOS/BadgeTests" -framework SystemConfiguration -framework Cocoa
"$badge_app/Contents/MacOS/BadgeTests"
