#!/bin/bash
# vendor_mozjpeg.sh — Download and prepare MozJPEG 3.3.1 source
# Created by okooo5km(十里)

set -euo pipefail

VERSION="3.3.1"
VENDOR_DIR="$(cd "$(dirname "$0")/.." && pwd)/Vendor"
TARGET_DIR="${VENDOR_DIR}/mozjpeg-${VERSION}"

if [ -d "$TARGET_DIR" ]; then
    echo "MozJPEG ${VERSION} already vendored at ${TARGET_DIR}"
    exit 0
fi

echo "Downloading MozJPEG ${VERSION}..."
mkdir -p "$VENDOR_DIR"
curl -sL "https://github.com/mozilla/mozjpeg/archive/v${VERSION}.tar.gz" | tar xz -C "$VENDOR_DIR"

echo "MozJPEG ${VERSION} vendored to ${TARGET_DIR}"
echo "Source files have been pre-copied to Sources/CMozJPEG/"
