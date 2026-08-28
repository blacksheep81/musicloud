#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
developer_dir="$(xcode-select -p)"
framework_dir="$developer_dir/Library/Developer/Frameworks"
if [[ "$developer_dir" == */CommandLineTools && -d "$framework_dir/Testing.framework" ]]; then
    swift test \
        -Xswiftc -F -Xswiftc "$framework_dir" \
        -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
        -Xlinker -F -Xlinker "$framework_dir" \
        -Xlinker -rpath -Xlinker "$framework_dir" "$@"
else
    swift test "$@"
fi
