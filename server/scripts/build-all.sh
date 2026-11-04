#!/bin/sh
# Builds obhijatra-server for every supported platform into dist/.
# Uses only the vendored sources (works with the network off) and no C
# compiler (CGO_ENABLED=0; PocketBase's SQLite driver is pure Go).
#
# Usage: scripts/build-all.sh [version]      e.g. scripts/build-all.sh 0.1.0
set -eu

cd "$(dirname "$0")/.."

VERSION="${1:-0.1.0-dev}"
LDFLAGS="-s -w -X github.com/obhijatra/obhijatra/server/internal/version.Version=${VERSION}"

mkdir -p dist

for target in linux/amd64 linux/arm64 windows/amd64 darwin/arm64; do
	os="${target%/*}"
	arch="${target#*/}"
	out="dist/obhijatra-server_${VERSION}_${os}_${arch}"
	[ "$os" = "windows" ] && out="${out}.exe"

	echo "building ${out}"
	CGO_ENABLED=0 GOOS="$os" GOARCH="$arch" GOFLAGS=-mod=vendor \
		go build -trimpath -buildvcs=false -ldflags "$LDFLAGS" -o "$out" ./cmd/obhijatra-server
done

(cd dist && sha256sum obhijatra-server_"${VERSION}"_* > "SHA256SUMS_${VERSION}")
echo "done: dist/SHA256SUMS_${VERSION}"
