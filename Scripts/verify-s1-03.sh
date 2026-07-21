#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$root"

simulator_udid=${THORCHAIN_SIMULATOR_UDID:-}
[[ "$simulator_udid" =~ ^[0-9A-Fa-f-]{36}$ ]] \
    || { echo "FAIL verify-s1-03: THORCHAIN_SIMULATOR_UDID must contain one UUID" >&2; exit 1; }

fail() { echo "FAIL verify-s1-03: $1" >&2; exit 1; }

expected_base=
expected_head=
fixtures_only=false
while (($#)); do
    case "$1" in
        --expected-base)
            (($# >= 2)) || fail "--expected-base requires a value"
            expected_base=$2
            shift 2
            ;;
        --expected-head)
            (($# >= 2)) || fail "--expected-head requires a value"
            expected_head=$2
            shift 2
            ;;
        --fixtures-only)
            fixtures_only=true
            shift
            ;;
        *) fail "unknown argument: $1" ;;
    esac
done

if [[ "$fixtures_only" == false ]]; then
    [[ "$expected_base" =~ ^[0-9a-f]{40}$ ]] || fail "expected base must be a 40-character SHA"
    [[ "$expected_head" =~ ^[0-9a-f]{40}$ ]] || fail "expected head must be a 40-character SHA"
    [[ "$(git rev-parse HEAD)" == "$expected_head" ]] || fail "HEAD is not the expected head"
    [[ -z "$(git status --porcelain)" ]] || fail "worktree is not clean"
    [[ "$(git rev-parse refs/remotes/origin/main)" == "$expected_base" ]] || fail "origin/main is not the expected base"
    git merge-base --is-ancestor "$expected_base" "$expected_head" || fail "expected base is not an ancestor of expected head"
fi

python3 - <<'PY'
from hashlib import sha256
from pathlib import Path
import json
import re

root = Path('.')
vectors = json.loads((root / 'Tests/ThorChainKitTests/Fixtures/AddressVectors.json').read_text())
assert vectors['schemaVersion'] == 1
assert len(vectors['sources']) == 4
assert len(vectors['vectors']) == 1

source_expectations = {
    'official-public-key-vector': (
        'https://github.com/vultisig/vultisig-ios.git',
        'd3123dbe6ef1103937c272a8b1cd81f613af0acc',
        'VultisigApp/VultisigAppTests/Chains/PublicKeyTest.swift:18-19',
    ),
    'independent-hash160': (
        'https://github.com/horizontalsystems/HsCryptoKit.Swift.git',
        '7c11ad0e690cbb178a70f3b9d1116d0a37a51a41',
        'Sources/HsCryptoKit/Crypto.swift:194-209',
    ),
    'independent-classic-bech32': (
        'https://github.com/horizontalsystems/BitcoinCore.Swift.git',
        '5b49f424f495904cf06519b1a7b861ef37b45b50',
        'Sources/BitcoinCore/Classes/SegWit/Bech32.swift:14-147,188-205',
    ),
    'thor-address-oracle': (
        'https://github.com/vultisig/vultisig-ios.git',
        'd3123dbe6ef1103937c272a8b1cd81f613af0acc',
        'VultisigApp/VultisigAppTests/TestData/thorchain.json:16',
    ),
}
for source in vectors['sources']:
    role = source['role']
    assert role in source_expectations
    assert (source['repository'], source['commit'], source['path']) == source_expectations[role]
    assert re.fullmatch(r'[0-9a-f]{40}', source['commit'])
    assert re.fullmatch(r'[0-9a-f]{64}', source['outputDigest'])
    assert source['command'] and source['inputOrigin'] and source['tool'] and source['version']
    assert not re.search(r'(/Users/|/private/|file://|mnemonic|seed phrase|private key)', json.dumps(source), re.I)

vector = vectors['vectors'][0]
assert vector == {
    'id': 'thorchain-account-0-0',
    'path': "m/44'/931'/0'/0/0",
    'compressedPublicKeyHex': '02a9ac9f7a97da41559e1684011b6a9b0b9c0445297d5f51dea0897fd4a39c31c7',
    'sha256Hex': '3cc06d8afebb6ba8310671a54c5c616b7b6c87e0dcdccf2a5bf33356e6a59a49',
    'payloadHex': '5a0dba49dab8fec87c6dd7c01b564ee72a8515a6',
    'mainnetAddress': 'thor1tgxm5jw6hrlvslrd6lqpk4jwuu4g29dxytrean',
    'stagenetAddress': 'sthor1tgxm5jw6hrlvslrd6lqpk4jwuu4g29dxsjl0td',
    'chainnetAddress': 'cthor1tgxm5jw6hrlvslrd6lqpk4jwuu4g29dxgmq2h0',
    'outputDigest': 'c198c6f92f12029403394759ee6fde166758a9e1916da333ef84f4e685966b10',
}
digest_input = '|'.join([
    vector['compressedPublicKeyHex'], vector['sha256Hex'], vector['payloadHex'],
    vector['mainnetAddress'], vector['stagenetAddress'], vector['chainnetAddress'],
])
assert sha256(digest_input.encode()).hexdigest() == vector['outputDigest']
assert set(vectors['negativeCases']) >= {
    'wrong compressed-key length', 'wrong compressed-key prefix',
    'off-curve compressed-key x-coordinate', 'wrong HRP', 'mixed case',
    'checksum mutation', 'invalid payload length', 'non-canonical path digits',
}

seed = (root / 'Tests/ThorChainKitTests/Fixtures/S1-03-fuzz-seed.txt').read_text()
assert seed == 'version=1\nalgorithm=splitmix64\nseed=0x534c30332d46555a\ncount=1024\n'

source_paths = [
    root / 'Sources/ThorChainKit/Crypto/DerivationPath.swift',
    root / 'Sources/ThorChainKit/Crypto/AccountAddressDeriving.swift',
    root / 'Sources/ThorChainKit/Crypto/AccountAddressFactory.swift',
    root / 'Sources/ThorChainKit/Crypto/CosmosAccountAddressDeriver.swift',
    root / 'Sources/ThorChainKit/Crypto/Secp256k1PublicKeyValidator.swift',
    root / 'Sources/ThorChainKit/Address/AddressCodec.swift',
    root / 'Sources/ThorChainKit/Address/BitConversion.swift',
    root / 'Sources/ThorChainKit/Address/Bech32Codec.swift',
    root / 'Sources/ThorChainKit/Models/Address.swift',
]
source = '\n'.join(path.read_text() for path in source_paths)
capability_lines = (root / 'Tests/ThorChainKitTests/Fixtures/S1-03-capability-closure.txt').read_text().splitlines()
capabilities = dict(line.split('=', 1) for line in capability_lines if line and not line.startswith('#'))
assert capabilities['root'] == 'AccountAddressFactory.address'
assert capabilities['boundary'] == 'compressedPublicKey-only'
required_markers = {
    'Secp256k1PublicKeyValidator.validate': 'validate(',
    'AccountAddressHasher.hash160': 'hash160(',
    'AddressCodec.encode': 'func encode(payload:',
    'Address.init': 'init(_ raw:',
    'BitConversion.convert': 'static func convert(',
    'Bech32Codec.encode': 'static func encode(hrp:',
}
assert set(capabilities['allowed'].split(',')) == set(required_markers)
assert all(marker in source for marker in required_markers.values())
assert all(forbidden not in source for forbidden in capabilities['forbidden'].split(','))
assert source.count('struct CosmosAccountAddressDeriver: AccountAddressDeriving, Sendable') == 1
assert 'struct CosmosAccountAddressDeriver: AccountAddressDeriving, Sendable' in (root / 'Sources/ThorChainKit/Crypto/CosmosAccountAddressDeriver.swift').read_text()
assert 'import HsCryptoKit' in source
assert 'RIPEMD160' not in source
assert 'import UIKit' not in source and 'import SwiftUI' not in source
assert 'import HdWalletKit' not in source and 'import WalletCore' not in source
assert 'try!' not in source and 'try?' not in source and 'fatalError' not in source and 'precondition' not in source
assert 'mnemonic' not in source.lower() and 'private key' not in source.lower() and 'seed' not in source.lower()
package = (root / 'Package.swift').read_text()
assert 'name: "HsCryptoKit"' in package and 'package: "HsCryptoKit.Swift"' in package
assert 'condition: .when(platforms:' not in package[package.index('name: "HsCryptoKit"'):package.index('name: "secp256k1"')]

revisions = {}
for line in (root / 'Tests/ThorChainKitTests/Fixtures/S1-03-dependency-revisions.txt').read_text().splitlines():
    if not line or line.startswith('#'):
        continue
    identity, location, version, revision = line.split('|')
    revisions[identity] = (location, version, revision)
lock = json.loads((root / 'Package.resolved').read_text())
pins = {pin['identity']: pin for pin in lock['pins']}
assert set(pins) == set(revisions)
for identity, (location, version, revision) in revisions.items():
    assert pins[identity]['location'] == location
    assert pins[identity]['state'] == {'revision': revision, 'version': version}

tests = (root / 'Tests/ThorChainKitTests/AddressCodecTests.swift').read_text()
for marker in ['testBIP173Vectors', 'testBitConversionPaddingKnownAnswers', 'testDeterministicFuzzReplay', 'testArbitraryUTF8NeverTraps', 'testPayloadBoundaryLengthsFailClosed']:
    assert marker in tests
derivation_tests = (root / 'Tests/ThorChainKitTests/DerivationTests.swift').read_text()
assert '٠' in derivation_tests
public_symbols = (root / 'Tests/ThorChainKitTests/Fixtures/S1-03-public-symbols.txt').read_text().splitlines()
public_markers = {
    'AccountAddressError': 'enum AccountAddressError',
    'AccountAddressFactory.address(compressedPublicKey:network:)': 'public static func address(',
    'AddressCodec': 'public struct AddressCodec',
    'AddressCodec.decode(_:network:)': 'func decode(_ string:',
    'AddressCodec.encode(payload:network:)': 'func encode(payload:',
    'DerivationPath': 'struct DerivationPath',
    'DerivationPath.defaultAccount': 'static let defaultAccount',
    'DerivationPathError': 'enum DerivationPathError',
}
assert set(public_symbols) == set(public_markers)
assert all(marker in source for marker in public_markers.values())
discovery = (root / 'Tests/ThorChainKitTests/Fixtures/S1-03-tests.txt').read_text()
for marker in [
    'AddressCodecTests/testBIP173Vectors',
    'AddressCodecTests/testBitConversionPaddingKnownAnswers',
    'AddressCodecTests/testDeterministicFuzzReplay',
    'AddressCodecTests/testArbitraryUTF8NeverTraps',
]:
    assert marker in discovery
print('PASS verify-s1-03-source-fixtures')
PY

if [[ "$fixtures_only" == false ]]; then
    run_tests() {
        local label=$1 selector=$2 allowlist=$3
        local derived_data result_bundle
        local -a selection=()
        [[ -z "$selector" ]] || selection=("-only-testing:ThorChainKitTests/$selector")
        derived_data=$(mktemp -d)
        result_bundle=$(mktemp -d)/"$label.xcresult"
        : "${derived_data:?derived-data path missing}"
        : "${result_bundle:?xcresult path missing}"
        xcodebuild -scheme ThorChainKit \
            -destination "platform=iOS Simulator,id=${simulator_udid}" \
            -derivedDataPath "$derived_data" \
            -resultBundlePath "$result_bundle" \
            SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
            "${selection[@]}" \
            CODE_SIGNING_ALLOWED=NO test
        Scripts/verify-xcresult.sh "verify-s1-03-$label" "$result_bundle" "$allowlist"
    }

    derivation_allowlist=$(mktemp)
    codec_allowlist=$(mktemp)
    full_allowlist=$(mktemp)
    trap 'rm -f "$derivation_allowlist" "$codec_allowlist" "$full_allowlist"' EXIT
    rg '^ThorChainKitTests\.DerivationTests/' Tests/ThorChainKitTests/Fixtures/S1-03-tests.txt > "$derivation_allowlist"
    rg '^ThorChainKitTests\.AddressCodecTests/' Tests/ThorChainKitTests/Fixtures/S1-03-tests.txt > "$codec_allowlist"
    cat Tests/ThorChainKitTests/Fixtures/S1-01-tests.txt \
        Tests/ThorChainKitTests/Fixtures/S1-02-tests.txt \
        Tests/ThorChainKitTests/Fixtures/S1-03-tests.txt \
        | sort -u > "$full_allowlist"
    run_tests derivation DerivationTests "$derivation_allowlist"
    run_tests codec AddressCodecTests "$codec_allowlist"
    run_tests full '' "$full_allowlist"
fi
echo "PASS verify-s1-03"
