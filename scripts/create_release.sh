#!/bin/bash
# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) 2026, Coccinella Labs. All rights reserved.

set -euo pipefail

VERSION=$(tr -d '[:space:]' < VERSION)
TAG_NAME="v${VERSION}"
TARGET_SHA="${GITHUB_SHA:-$(git rev-parse HEAD)}"
DRY_RUN="${DRY_RUN:-false}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "[ERROR] VERSION must contain a single semantic version, found: ${VERSION}" >&2
    exit 1
fi

echo "[INFO] Preparing release ${TAG_NAME}"
echo "[INFO] Dry run: ${DRY_RUN}"

if gh release view "$TAG_NAME" >/dev/null 2>&1; then
    echo "[SKIP] Release ${TAG_NAME} already exists"
    exit 0
fi

if git ls-remote --exit-code --tags origin "refs/tags/${TAG_NAME}" >/dev/null 2>&1; then
    echo "[INFO] Remote tag ${TAG_NAME} already exists"
    git fetch --tags origin "${TAG_NAME}:${TAG_NAME}" >/dev/null 2>&1 || true
    EXISTING_SHA="$(git rev-list -n 1 "${TAG_NAME}")"
    if [[ "$EXISTING_SHA" != "$TARGET_SHA" ]]; then
        echo "[ERROR] Existing tag ${TAG_NAME} points to ${EXISTING_SHA}, expected ${TARGET_SHA}" >&2
        exit 1
    fi
else
    echo "[INFO] Creating tag ${TAG_NAME} at ${TARGET_SHA}"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] Would create and push tag ${TAG_NAME} at ${TARGET_SHA}"
    else
        git tag -a "$TAG_NAME" -m "Release ${TAG_NAME}" "${TARGET_SHA}"
        git push origin "$TAG_NAME"
    fi
fi

echo "[INFO] Creating GitHub release ${TAG_NAME}"
if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY RUN] Would create GitHub release ${TAG_NAME} with generated notes"
else
    gh release create "$TAG_NAME" \
        --title "$TAG_NAME" \
        --generate-notes \
        --latest
fi

echo "[PASS] Release published: ${TAG_NAME}"
