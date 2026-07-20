#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$root"

fail() { echo "FAIL verify-s1-03: $1" >&2; exit 1; }

python3 - <<'PY' || exit 1
from pathlib import Path
import json

root = Path('.')
spec = (root / 'docs/specs/sprint-01-foundation/S1-03-derivation-address-codec.md').read_text()
manifest = (root / '.maestro/S1-03-analog-manifest.txt').read_text()
vectors = json.loads((root / 'Tests/ThorChainKitTests/Fixtures/AddressVectors.json').read_text())
deps = (root / 'Tests/ThorChainKitTests/Fixtures/S1-03-dependency-revisions.txt').read_text()
fuzz = (root / 'Tests/ThorChainKitTests/Fixtures/S1-03-fuzz-seed.txt').read_text()

assert len(vectors['vectors']) == 1
vector = vectors['vectors'][0]
assert vector['path'] == "m/44'/931'/0'/0/0"
assert vector['publicKey'] == '02a9ac9f7a97da41559e1684011b6a9b0b9c0445297d5f51dea0897fd4a39c31c7'
assert vector['hash160'] == '5a0dba49dab8fec87c6dd7c01b564ee72a8515a6'
assert vector['mainnetAddress'] == 'thor1tgxm5jw6hrlvslrd6lqpk4jwuu4g29dxytrean'
assert all(value in manifest for value in [
    'https://github.com/horizontalsystems/HdWalletKit.Swift.git',
    'https://github.com/horizontalsystems/HsCryptoKit.Swift.git',
    'https://github.com/horizontalsystems/BitcoinCore.Swift.git',
    'https://github.com/vultisig/vultisig-ios.git',
])
assert all(value in deps for value in [
    'bigint|https://github.com/attaswift/BigInt.git|5.7.0|e07e00fa1fd435143a2dcf8b7eec9a7710b2fdfe',
    'hscryptokit.swift|https://github.com/horizontalsystems/HsCryptoKit.Swift.git|1.3.2|7c11ad0e690cbb178a70f3b9d1116d0a37a51a41',
    'hsextensions.swift|https://github.com/horizontalsystems/HsExtensions.Swift.git|1.0.6|0012014f98ae81ffb89b0d3a2e9c204559e1c278',
    'secp256k1.swift|https://github.com/GigaBitcoin/secp256k1.swift.git|0.10.0|48fb20fce4ca3aad89180448a127d5bc16f0e44c',
    'swift-crypto|https://github.com/apple/swift-crypto.git|2.6.0|60f13f60c4d093691934dc6cfdf5f508ada1f894',
])
assert 'count=1024' in fuzz and 'outputs-per-case=3' in fuzz
source_paths = [
    root / 'Sources/ThorChainKit/Crypto/DerivationPath.swift',
    root / 'Sources/ThorChainKit/Crypto/AccountAddressDeriving.swift',
    root / 'Sources/ThorChainKit/Crypto/AccountAddressFactory.swift',
    root / 'Sources/ThorChainKit/Crypto/CosmosAccountAddressDeriver.swift',
    root / 'Sources/ThorChainKit/Crypto/Secp256k1PublicKeyValidator.swift',
    root / 'Sources/ThorChainKit/Address/AddressCodec.swift',
]
source = '\n'.join(path.read_text() for path in source_paths)
assert 'import UIKit' not in source and 'import SwiftUI' not in source
assert 'import HdWalletKit' not in source and 'import WalletCore' not in source
assert 'try!' not in source and 'try?' not in source and 'fatalError' not in source and 'precondition' not in source
assert 'mnemonic' not in source.lower() and 'private key' not in source.lower() and 'seed' not in source.lower()
assert 'public func decode(_ string: String, network: Network) throws -> Address' in source
assert 'try Address(string, network: network)' in source
assert 'public static func address(' in source and 'compressedPublicKey: Data' in source
print('PASS verify-s1-03-source-closure')
PY

swift test --filter DerivationTests
swift test --filter AddressCodecTests
swift test
Scripts/test-s1-03-mutants.sh
echo "PASS verify-s1-03"
