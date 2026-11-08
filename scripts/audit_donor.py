#!/usr/bin/env python3
"""Read-only compatibility audit; never imports donor hardware settings."""
from __future__ import annotations
import argparse
import re
from pathlib import Path

KEYS = [
    "TARGET_ARCH", "TARGET_ARCH_VARIANT", "TARGET_BOARD_PLATFORM",
    "BOARD_BOOTIMG_HEADER_VERSION", "BOARD_KERNEL_BASE",
    "BOARD_KERNEL_PAGESIZE", "BOARD_RAMDISK_OFFSET",
    "BOARD_KERNEL_TAGS_OFFSET", "BOARD_BOOTIMAGE_PARTITION_SIZE",
    "BOARD_RECOVERYIMAGE_PARTITION_SIZE", "BOARD_INCLUDE_RECOVERY_DTBO",
    "BOARD_SUPER_PARTITION_SIZE", "TW_INCLUDE_CRYPTO", "TW_INCLUDE_CRYPTO_FBE",
    "TW_THEME", "TW_BRIGHTNESS_PATH", "TW_DEFAULT_BRIGHTNESS",
]


def parse_config(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    for raw in path.read_text(errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or ":=" not in line and "=" not in line:
            continue
        match = re.match(r"([A-Za-z0-9_]+)\s*(?::=|=)\s*(.*)$", line)
        if match and match.group(1) in KEYS:
            out[match.group(1)] = match.group(2).strip().rstrip("\\")
    return out


def locate_boardconfig(root: Path, specified: str) -> list[Path]:
    if specified:
        candidate = root / specified / "BoardConfig.mk"
        return [candidate] if candidate.is_file() else []
    found: list[Path] = []
    for path in root.rglob("BoardConfig.mk"):
        if ".git" in path.parts or "out" in path.parts:
            continue
        found.append(path)
        if len(found) >= 25:
            break
    return found


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", required=True, type=Path)
    parser.add_argument("--donor-root", type=Path)
    parser.add_argument("--donor-path", default="")
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    if not args.target.is_file():
        raise SystemExit(f"Target BoardConfig missing: {args.target}")
    target = parse_config(args.target)
    donor = {}
    donor_file = None
    candidate_list: list[Path] = []
    if args.donor_root and args.donor_root.exists():
        candidate_list = locate_boardconfig(args.donor_root, args.donor_path)
        if len(candidate_list) == 1:
            donor_file = candidate_list[0]
            donor = parse_config(donor_file)

    lines = [
        "# Donor recovery compatibility audit", "",
        "> Read-only comparison. No donor device settings are copied into the X688B tree.", "",
        f"- X688B target config: `{args.target}`",
    ]
    if donor_file:
        lines.append(f"- Donor config: `{donor_file}`")
    elif args.donor_root:
        lines.append("- Donor config: not uniquely identified")
        if candidate_list:
            lines += ["", "Candidate `BoardConfig.mk` files:"]
            lines += [f"- `{p.relative_to(args.donor_root)}`" for p in candidate_list]
        else:
            lines.append("- No `BoardConfig.mk` found in donor repository.")
        lines.append("- Re-run with `donor_device_tree_path` pointing to the folder that contains `BoardConfig.mk`.")
    else:
        lines.append("- Donor config: not supplied")

    lines += ["", "## Configuration comparison", "", "| Key | X688B target | Donor reference | Result |", "|---|---|---|---|"]
    for key in KEYS:
        tv, dv = target.get(key, "(not set)"), donor.get(key, "(not set)")
        result = "same" if donor and tv == dv else ("different — keep X688B value" if donor and tv != dv else "reference only")
        lines.append(f"| `{key}` | `{tv}` | `{dv}` | {result} |")

    lines += [
        "", "## Porting rules", "",
        "1. Keep X688B kernel, DTB, DTBO, partition sizes, offsets, and hardware paths from target firmware/tree.",
        "2. Do not copy the donor `BoardConfig.mk`, `fstab`, kernel, DTB, vendor blobs, or SELinux policy wholesale.",
        "3. Donor UI/theme/resources or generic TWRP features need individual review for path and dependency compatibility.",
        "4. A successful compile does not prove touchscreen, decryption, MTP, ADB, fastbootd, or dynamic partitions work.",
        "", "## X688B-specific checks", "",
        f"- Platform expected by this tree: `mt6765` (actual parsed: `{target.get('TARGET_BOARD_PLATFORM', '(not set)')}`).",
        f"- Boot header expected by this tree: `2` (actual parsed: `{target.get('BOARD_BOOTIMG_HEADER_VERSION', '(not set)')}`).",
        f"- Recovery partition size from this tree: `{target.get('BOARD_RECOVERYIMAGE_PARTITION_SIZE', '(not set)')}` bytes.",
        "- Target firmware label is user-provided and is not independently authenticated by this report.",
    ]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines) + "\n")
    print(f"Audit written: {args.output}")
    if args.donor_root and not donor_file:
        print("WARNING: donor BoardConfig not uniquely identified; audit is partial.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
