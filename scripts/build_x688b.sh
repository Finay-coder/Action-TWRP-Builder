#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$ROOT/artifacts"
WORK="$RUNNER_TEMP/x688b-recovery-work"
TREE_URL="https://github.com/NeonzDump/twrp_infinix_X688B.git"
TREE_BRANCH="11"
MANIFEST_URL="https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git"
MANIFEST_BRANCH="twrp-11"
TARGET_TREE="$WORK/device/infinix/X688B"
BOOT_IMAGE="$ROOT/stock/boot.img"
TARGET_RECOVERY_LIMIT=40894464
TARGET_BOOT_PARTITION_SIZE=33554432

mkdir -p "$ARTIFACTS" "$WORK"
cat > "$ARTIFACTS/build-report.md" <<REPORT
# X688B TWRP 11 build report

- Target label: ${TARGET_BUILD:-not supplied}
- Mode: ${BUILD_MODE:-audit}
- Device tree: $TREE_URL (branch $TREE_BRANCH)
- Manifest: $MANIFEST_URL (branch $MANIFEST_BRANCH)
- Device: Infinix Hot 11 Play X688B / MT6765
- Android target: 11
- Output recovery partition limit: $TARGET_RECOVERY_LIMIT bytes
- Build status: started
REPORT

fail() {
  echo "ERROR: $*" >&2
  echo "- Build status: FAILED — $*" >> "$ARTIFACTS/build-report.md"
  exit 1
}

safe_branch() {
  [[ "$1" =~ ^[A-Za-z0-9._/-]+$ ]] || fail "Invalid branch value."
}

# Restrict donor input to a public GitHub repository URL. Donor code is never executed.
if [[ -n "${DONOR_GITHUB_URL:-}" ]]; then
  [[ "$DONOR_GITHUB_URL" =~ ^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(\.git)?/?$ ]] || fail "Donor URL must be a public GitHub repository URL: https://github.com/OWNER/REPO"
  safe_branch "${DONOR_BRANCH:-main}"
fi

if [[ "${BUILD_MODE:-audit}" != "audit" && "${BUILD_MODE:-audit}" != "build" ]]; then
  fail "Mode must be audit or build."
fi

# Fetch the device-specific target tree. It remains authoritative for hardware config.
mkdir -p "$WORK/device/infinix"
git clone --depth=1 --branch "$TREE_BRANCH" "$TREE_URL" "$TARGET_TREE"
TREE_COMMIT="$(git -C "$TARGET_TREE" rev-parse HEAD)"
echo "- X688B tree commit: $TREE_COMMIT" >> "$ARTIFACTS/build-report.md"

DONOR_DIR=""
if [[ -n "${DONOR_GITHUB_URL:-}" ]]; then
  DONOR_DIR="$WORK/donor_reference"
  git clone --depth=1 --branch "${DONOR_BRANCH:-main}" "$DONOR_GITHUB_URL" "$DONOR_DIR"
  DONOR_COMMIT="$(git -C "$DONOR_DIR" rev-parse HEAD)"
  echo "- Donor repository: $DONOR_GITHUB_URL (branch ${DONOR_BRANCH:-main}, commit $DONOR_COMMIT)" >> "$ARTIFACTS/build-report.md"
else
  echo "- Donor repository: not supplied" >> "$ARTIFACTS/build-report.md"
fi

AUDIT_ARGS=(--target "$TARGET_TREE/BoardConfig.mk" --output "$ARTIFACTS/donor-audit.md")
if [[ -n "$DONOR_DIR" ]]; then
  AUDIT_ARGS+=(--donor-root "$DONOR_DIR")
fi
if [[ -n "${DONOR_DEVICE_TREE_PATH:-}" ]]; then
  AUDIT_ARGS+=(--donor-path "$DONOR_DEVICE_TREE_PATH")
fi
python3 "$ROOT/scripts/audit_donor.py" "${AUDIT_ARGS[@]}"

if [[ "$BUILD_MODE" == "audit" ]]; then
  echo "- Build status: AUDIT COMPLETE (no recovery image compiled)" >> "$ARTIFACTS/build-report.md"
  exit 0
fi

# Get V788 stock boot image. Direct URL must return the binary, not an HTML page.
if [[ -n "${STOCK_BOOT_URL:-}" ]]; then
  [[ "$STOCK_BOOT_URL" =~ ^https:// ]] || fail "stock_boot_url must use HTTPS."
  curl --fail --location --retry 3 --retry-delay 2 "$STOCK_BOOT_URL" -o "$WORK/stock-boot.img"
  BOOT_IMAGE="$WORK/stock-boot.img"
fi
[[ -s "$BOOT_IMAGE" ]] || fail "No stock boot image. Add stock/boot.img or set stock_boot_url. Build mode requires the original X688B V788 boot.img."
BOOT_SIZE="$(stat -c '%s' "$BOOT_IMAGE")"
if (( BOOT_SIZE > TARGET_BOOT_PARTITION_SIZE )); then
  fail "Stock boot image is $BOOT_SIZE bytes, larger than X688B boot partition size $TARGET_BOOT_PARTITION_SIZE bytes. Check that this is the correct raw boot.img."
fi
BOOT_SHA="$(sha256sum "$BOOT_IMAGE" | awk '{print $1}')"
echo "- Stock boot image size: $BOOT_SIZE bytes" >> "$ARTIFACTS/build-report.md"
echo "- Stock boot image SHA-256: $BOOT_SHA" >> "$ARTIFACTS/build-report.md"

# Download official Magisk APK only to obtain its host-side magiskboot image unpacker.
MAGISK_APK="$WORK/Magisk.apk"
MAGISK_APK_URL="$(python3 - <<'PYMAGISK'
import json
import urllib.request
request = urllib.request.Request(
    "https://api.github.com/repos/topjohnwu/Magisk/releases/latest",
    headers={"Accept": "application/vnd.github+json", "User-Agent": "X688B-Recovery-Builder"},
)
with urllib.request.urlopen(request, timeout=30) as response:
    release = json.load(response)
assets = release.get("assets", [])
match = next((a["browser_download_url"] for a in assets
              if a.get("name", "").startswith("Magisk-v") and a.get("name", "").endswith(".apk")), None)
if not match:
    raise SystemExit("Could not locate official Magisk APK asset in latest release")
print(match)
PYMAGISK
)" || fail "Could not locate latest official Magisk APK."
curl --fail --location --retry 3 "$MAGISK_APK_URL" -o "$MAGISK_APK"
command -v unzip >/dev/null 2>&1 || fail "unzip is required."
unzip -Z1 "$MAGISK_APK" | grep -qx 'lib/x86_64/libmagiskboot.so' || fail "Could not find x86_64 magiskboot in official Magisk APK."
unzip -p "$MAGISK_APK" lib/x86_64/libmagiskboot.so > "$WORK/magiskboot"
chmod 0755 "$WORK/magiskboot"

UNPACK_DIR="$WORK/boot-unpack"
mkdir -p "$UNPACK_DIR"
cp "$BOOT_IMAGE" "$UNPACK_DIR/boot.img"
(
  cd "$UNPACK_DIR"
  "$WORK/magiskboot" unpack boot.img
)
[[ -s "$UNPACK_DIR/kernel" ]] || fail "magiskboot did not extract a kernel from the stock boot image."
cp "$UNPACK_DIR/kernel" "$TARGET_TREE/prebuilt/kernel"
KERNEL_SIZE="$(stat -c '%s' "$TARGET_TREE/prebuilt/kernel")"
echo "- Extracted target kernel: $KERNEL_SIZE bytes" >> "$ARTIFACTS/build-report.md"

# Prefer DTB extracted from boot.img; allow a separately supplied stock/dtb.img.
if [[ -s "$ROOT/stock/dtb.img" ]]; then
  cp "$ROOT/stock/dtb.img" "$TARGET_TREE/prebuilt/dtb.img"
elif [[ -s "$UNPACK_DIR/dtb" ]]; then
  cp "$UNPACK_DIR/dtb" "$TARGET_TREE/prebuilt/dtb.img"
else
  fail "No DTB found in stock boot image. Put the correct V788 DTB at stock/dtb.img; do not substitute a donor DTB."
fi
DTB_SIZE="$(stat -c '%s' "$TARGET_TREE/prebuilt/dtb.img")"
echo "- Target DTB size: $DTB_SIZE bytes" >> "$ARTIFACTS/build-report.md"

# Optional V788 DTBO replacement. Leave the target tree's DTBO unchanged if absent.
if [[ -n "${STOCK_DTBO_URL:-}" ]]; then
  [[ "$STOCK_DTBO_URL" =~ ^https:// ]] || fail "stock_dtbo_url must use HTTPS."
  curl --fail --location --retry 3 "$STOCK_DTBO_URL" -o "$WORK/dtbo.img"
  [[ -s "$WORK/dtbo.img" ]] || fail "Downloaded DTBO is empty."
  cp "$WORK/dtbo.img" "$TARGET_TREE/prebuilt/dtbo.img"
elif [[ -s "$ROOT/stock/dtbo.img" ]]; then
  cp "$ROOT/stock/dtbo.img" "$TARGET_TREE/prebuilt/dtbo.img"
fi

# Build environment. GitHub runner disk availability is checked before syncing the full source.
FREE_KB="$(df -Pk "$WORK" | awk 'NR==2 {print $4}')"
if (( FREE_KB < 30000000 )); then
  fail "Less than 30 GB free disk space before Android source sync. Use a runner with more disk space or run audit mode."
fi

mkdir -p "$WORK/twrp"
cd "$WORK/twrp"
curl --fail --location https://storage.googleapis.com/git-repo-downloads/repo -o "$RUNNER_TEMP/repo"
chmod +x "$RUNNER_TEMP/repo"
export PATH="$RUNNER_TEMP:$PATH"
git config --global user.name "X688B Recovery Builder"
git config --global user.email "actions@users.noreply.github.com"
repo init -u "$MANIFEST_URL" -b "$MANIFEST_BRANCH" --depth=1
repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune --force-sync -j2

mkdir -p device/infinix
cp -a "$TARGET_TREE" device/infinix/X688B

set +u  # Android build scripts assume some unset environment variables are allowed.
source build/envsetup.sh
lunch twrp_X688B-eng
mka -j2 recoveryimage
set -u

BUILT_IMAGE="$WORK/twrp/out/target/product/X688B/recovery.img"
[[ -s "$BUILT_IMAGE" ]] || fail "Build finished without out/target/product/X688B/recovery.img."
IMAGE_SIZE="$(stat -c '%s' "$BUILT_IMAGE")"
if (( IMAGE_SIZE > TARGET_RECOVERY_LIMIT )); then
  fail "Built recovery is $IMAGE_SIZE bytes, above target partition limit $TARGET_RECOVERY_LIMIT bytes. Image not exported as flash candidate."
fi
cp "$BUILT_IMAGE" "$ARTIFACTS/recovery.img"
IMAGE_SHA="$(sha256sum "$ARTIFACTS/recovery.img" | awk '{print $1}')"
echo "- Recovery image size: $IMAGE_SIZE bytes" >> "$ARTIFACTS/build-report.md"
echo "- Recovery image SHA-256: $IMAGE_SHA" >> "$ARTIFACTS/build-report.md"
echo "- Build status: BUILD SUCCESS (boot/functionality still unverified on hardware)" >> "$ARTIFACTS/build-report.md"
