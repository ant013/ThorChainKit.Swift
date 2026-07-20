#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$root"

fail() { echo "FAIL test-s1-03-mutants: $1" >&2; exit 1; }

view_model='iOS Example/Sources/Presentation/AddressViewModel.swift'
grep -F 'AccountAddressFactory.address(' "$view_model" >/dev/null || fail 'Example bypasses the real derivation factory'
grep -F 'codec.decode(' "$view_model" >/dev/null || fail 'Example bypasses the real codec decoder'
grep -F 'codec.encode(' "$view_model" >/dev/null || fail 'Example bypasses the real codec encoder'
grep -F 'address-codec-open' 'iOS Example/Sources/Views/DiagnosticsView.swift' >/dev/null || fail 'Example navigation does not reach address codec'
grep -F '02-address-codec.yaml' .maestro/config.yaml >/dev/null || fail 'address flow is not in the manifest'

echo 'PASS test-s1-03-mutants'
