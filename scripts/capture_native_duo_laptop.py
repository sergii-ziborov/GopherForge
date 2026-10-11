#!/usr/bin/env python3
"""Capture the actual Duo inner display after each verified laptop UI state.

Select the owned Duo's Partially Open posture and portrait orientation in
Device Hub first. Build GopherForgeScreenshots in Release with build-for-testing.
Requires Pillow, the same dependency used by the screenshot export workflow.
No device posture override or screen recording is used.
"""

import argparse
from pathlib import Path
import re
import subprocess
import time

from PIL import Image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True)
    parser.add_argument("--output-prefix", default="build/release-1.1/native-duo-laptop-frames-build18")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = root / args.output_prefix
    output.mkdir(parents=True, exist_ok=True)
    result = output.with_suffix(".xcresult")
    if result.exists():
        raise SystemExit(f"Keep existing evidence; choose a fresh result path: {result}")

    # Public enumeration distinguishes the active inner LCD from the inactive
    # outer LCD that XCTest currently captures in the laptop posture.
    enumeration = subprocess.run(
        ["xcrun", "simctl", "io", args.device, "enumerate"],
        check=True, text=True, capture_output=True, timeout=60,
    ).stdout
    inner = next((block for block in enumeration.split("    (")
                  if "Pixel Size: {2007, 2853}" in block), None)
    match = re.search(r"Device Name: ([^\n]+)", inner or "")
    if not match:
        raise SystemExit("The native Duo inner display was not enumerated")
    display = match.group(1).strip()
    (output / "display-enumeration.txt").write_text(enumeration)

    names = {"duo-laptop-code", "duo-laptop-terminal", "duo-laptop-idioms"}
    captured = set()
    command = [
        "xcodebuild", "-project", "GopherForge.xcodeproj", "-scheme", "GopherForgeScreenshots",
        "-configuration", "Release", "-destination", f"platform=iOS Simulator,id={args.device}",
        "-destination-timeout", "180", "-derivedDataPath", "DerivedDataScreenshots",
        "-collect-test-diagnostics", "never", "-disableAutomaticPackageResolution",
        "-parallel-testing-enabled", "NO", "-jobs", "2", "ONLY_ACTIVE_ARCH=YES",
        "SWIFT_SUPPRESS_WARNINGS=NO",
        "-only-testing:GopherForgeUITests/AppStoreScreenshotUITests/testCaptureNativeLaptopScreenshots",
        "-resultBundlePath", str(result), "test-without-building",
    ]
    logfile = output / "capture.log"
    deadline = time.monotonic() + 900
    with logfile.open("w") as log:
        process = subprocess.Popen(command, cwd=root, stdout=log, stderr=subprocess.STDOUT)
        try:
            while process.poll() is None:
                text = logfile.read_text()
                for name in names - captured:
                    if f"GF_NATIVE_FRAME_READY: {name}" not in text:
                        continue
                    raw = output / f"{name}.png"
                    subprocess.run(
                        ["xcrun", "simctl", "io", args.device, "screenshot",
                         f"--display={display}", str(raw)], check=True, timeout=25,
                    )
                    with Image.open(raw) as image:
                        rgb = image.convert("RGB")
                        if image.size != (2007, 2853) or not any(high - low > 100 for low, high in rgb.getextrema()):
                            raise RuntimeError(f"Reject blank or wrong-display capture: {name}")
                        rgb.save(root / "docs/screenshots" / f"{name}.png",
                                 icc_profile=image.info.get("icc_profile"))
                    captured.add(name)
                    print(f"Captured native inner display: {name}", flush=True)
                if time.monotonic() > deadline:
                    raise TimeoutError("Native capture exceeded 15 minutes")
                time.sleep(0.5)
            if process.returncode != 0 or captured != names:
                raise RuntimeError(f"Capture failed; inspect {logfile}")
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=30)
    print("All three native laptop captures completed; visually inspect before publishing.")


if __name__ == "__main__":
    main()
