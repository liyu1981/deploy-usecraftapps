#!/usr/bin/env bash
#
# Deprecated: this repository now deploys the whole suite of Craft apps.
# Kept for backwards compatibility; delegates to update-crafts.sh.
exec "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/update-crafts.sh" "$@"
