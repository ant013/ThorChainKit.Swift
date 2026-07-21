#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd -P)
temporary_root=$(mktemp -d)
trap 'rm -rf "$temporary_root"' EXIT

fail() { echo "FAIL test-s1-03-mutants: $1" >&2; exit 1; }

copy_contract() {
    local destination=$1
    mkdir -p "$destination/Sources/ThorChainKit/Crypto" \
        "$destination/Sources/ThorChainKit/Address" \
        "$destination/Sources/ThorChainKit/Models" \
        "$destination/Tests/ThorChainKitTests/Fixtures" \
        "$destination/iOS Example/Sources/Presentation" \
        "$destination/iOS Example/Sources/Views" \
        "$destination/iOS Example/Sources" \
        "$destination/.maestro/flows" \
        "$destination/Scripts"
    cp "$root/Scripts/verify-s1-03.sh" "$destination/Scripts/"
    cp "$root/Package.swift" "$root/Package.resolved" "$destination/"
    cp "$root/Tests/ThorChainKitTests/Fixtures/AddressVectors.json" \
        "$root/Tests/ThorChainKitTests/Fixtures/S1-03-"*.txt \
        "$destination/Tests/ThorChainKitTests/Fixtures/"
    cp "$root/Tests/ThorChainKitTests/AddressCodecTests.swift" "$destination/Tests/ThorChainKitTests/"
    cp "$root/Tests/ThorChainKitTests/DerivationTests.swift" "$destination/Tests/ThorChainKitTests/"
    cp "$root/Sources/ThorChainKit/Crypto/DerivationPath.swift" "$destination/Sources/ThorChainKit/Crypto/"
    cp "$root/Sources/ThorChainKit/Crypto/AccountAddressDeriving.swift" "$destination/Sources/ThorChainKit/Crypto/"
    cp "$root/Sources/ThorChainKit/Crypto/AccountAddressFactory.swift" "$destination/Sources/ThorChainKit/Crypto/"
    cp "$root/Sources/ThorChainKit/Crypto/CosmosAccountAddressDeriver.swift" "$destination/Sources/ThorChainKit/Crypto/"
    cp "$root/Sources/ThorChainKit/Crypto/Secp256k1PublicKeyValidator.swift" "$destination/Sources/ThorChainKit/Crypto/"
    cp "$root/Sources/ThorChainKit/Address/AddressCodec.swift" "$destination/Sources/ThorChainKit/Address/"
    cp "$root/Sources/ThorChainKit/Address/BitConversion.swift" "$destination/Sources/ThorChainKit/Address/"
    cp "$root/Sources/ThorChainKit/Address/Bech32Codec.swift" "$destination/Sources/ThorChainKit/Address/"
    cp "$root/Sources/ThorChainKit/Models/Address.swift" "$destination/Sources/ThorChainKit/Models/"
    cp "$root/iOS Example/Sources/ThorChainExampleApp.swift" "$destination/iOS Example/Sources/"
    cp "$root/iOS Example/Sources/Presentation/AddressViewModel.swift" "$destination/iOS Example/Sources/Presentation/"
    cp "$root/iOS Example/Sources/Views/DiagnosticsView.swift" "$destination/iOS Example/Sources/Views/"
    cp "$root/iOS Example/Sources/Views/AddressView.swift" "$destination/iOS Example/Sources/Views/"
    cp "$root/.maestro/flows/02-address-codec.yaml" "$destination/.maestro/flows/"
}

check_reachable_contract() {
    local destination=$1
    python3 - "$destination" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
app = (root / 'iOS Example/Sources/ThorChainExampleApp.swift').read_text()
diagnostics = (root / 'iOS Example/Sources/Views/DiagnosticsView.swift').read_text()
view_model = (root / 'iOS Example/Sources/Presentation/AddressViewModel.swift').read_text()
flow = (root / '.maestro/flows/02-address-codec.yaml').read_text()
assert 'DiagnosticsView(model: diagnostics)' in app
assert 'NavigationLink(destination: AddressView(network: model.runtime.network))' in diagnostics
assert 'AccountAddressFactory.address(' in view_model
assert 'codec.decode(' in view_model and 'codec.encode(' in view_model
assert 'badChecksumResult' in view_model
assert 'thor1tgxm5jw6hrlvslrd6lqpk4jwuu4g29dxytrean' in flow
assert 'id: bad-checksum-result' in flow and 'text: invalidAddress' in flow
assert 'id: mixed-case-result' in flow and 'text: mixedCase' in flow
assert 'id: wrong-hrp-result' in flow and 'text: wrongHrp' in flow
PY
}

expect_failure() {
    local label=$1
    shift
    if "$@" >"$temporary_root/$label.log" 2>&1; then
        fail "$label mutant passed"
    fi
    echo "PASS $label"
}

baseline="$temporary_root/baseline"
copy_contract "$baseline"
check_reachable_contract "$baseline"

navigation="$temporary_root/navigation"
copy_contract "$navigation"
python3 - "$navigation/iOS Example/Sources/Views/DiagnosticsView.swift" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
source = path.read_text()
needle = '                NavigationLink(destination: AddressView(network: model.runtime.network)) {'
assert source.count(needle) == 1
path.write_text(source.replace(needle, '                NavigationLink(destination: EndpointsView(model: endpoints)) {', 1))
PY
expect_failure navigation-mutant check_reachable_contract "$navigation"

factory="$temporary_root/factory"
copy_contract "$factory"
python3 - "$factory/iOS Example/Sources/Presentation/AddressViewModel.swift" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
source = path.read_text()
needle = 'AccountAddressFactory.address('
assert source.count(needle) == 1
path.write_text(source.replace(needle, 'AddressCodec.address(', 1))
PY
expect_failure factory-bypass-mutant check_reachable_contract "$factory"

fixture="$temporary_root/fixture"
copy_contract "$fixture"
python3 - "$fixture/Tests/ThorChainKitTests/Fixtures/AddressVectors.json" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
source = path.read_text()
needle = 'c198c6f92f12029403394759ee6fde166758a9e1916da333ef84f4e685966b10'
assert source.count(needle) == 1
path.write_text(source.replace(needle, '0' * 64, 1))
PY
expect_failure verifier-fixture-digest-mutant "$fixture/Scripts/verify-s1-03.sh" --fixtures-only

error="$temporary_root/error"
copy_contract "$error"
python3 - "$error/.maestro/flows/02-address-codec.yaml" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
source = path.read_text()
needle = '    text: invalidAddress'
assert source.count(needle) == 1
path.write_text(source.replace(needle, '    text: accepted', 1))
PY
expect_failure hard-coded-error-mutant check_reachable_contract "$error"

address="$temporary_root/address"
copy_contract "$address"
python3 - "$address/.maestro/flows/02-address-codec.yaml" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
source = path.read_text()
needle = 'thor1tgxm5jw6hrlvslrd6lqpk4jwuu4g29dxytrean'
assert source.count(needle) == 2
path.write_text(source.replace(needle, 'thor1'))
PY
expect_failure prefix-only-address-mutant check_reachable_contract "$address"

echo 'PASS test-s1-03-mutants'
