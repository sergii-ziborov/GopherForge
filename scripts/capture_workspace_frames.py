#!/usr/bin/env python3
"""Capture public simulator display pixels during verified XCTest holds.

Use Device Hub to select a Duo posture first; this script never overrides it.
--display accepts the UUID or name returned by public simctl io enumerate.
"""

import argparse
from pathlib import Path
import subprocess
import time

from PIL import Image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True)
    parser.add_argument("--display", help="Omit for an ordinary single-display device")
    parser.add_argument("--test", required=True)
    parser.add_argument("--frame", action="append", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = root / args.output
    output.mkdir(parents=True, exist_ok=True)
    result = output.with_suffix(".xcresult")
    if result.exists():
        raise SystemExit("Choose a fresh result path; existing evidence is retained")
    log_path = output / "capture.log"
    names = set(args.frame)
    captured = set()
    command = [
        "xcodebuild", "-project", "GopherForge.xcodeproj", "-scheme", "GopherForgeScreenshots",
        "-configuration", "Release", "-destination", f"platform=iOS Simulator,id={args.device}",
        "-destination-timeout", "180", "-derivedDataPath", "DerivedDataScreenshots",
        "-collect-test-diagnostics", "never", "-disableAutomaticPackageResolution",
        "-parallel-testing-enabled", "NO", "-jobs", "2", "ONLY_ACTIVE_ARCH=YES",
        "SWIFT_SUPPRESS_WARNINGS=NO", f"-only-testing:GopherForgeUITests/{args.test}",
        "-resultBundlePath", str(result), "test-without-building",
    ]
    with log_path.open("w") as log:
        process = subprocess.Popen(command, cwd=root, stdout=log, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 900
            while process.poll() is None:
                text = log_path.read_text()
                for name in names - captured:
                    if f"GF_NATIVE_FRAME_READY: {name}" not in text:
                        continue
                    path = output / f"{name}.png"
                    screenshot = ["xcrun", "simctl", "io", args.device, "screenshot"]
                    if args.display:
                        screenshot.append(f"--display={args.display}")
                    subprocess.run(screenshot + [str(path)], check=True, timeout=30)
                    with Image.open(path) as image:
                        if not any(high - low > 100 for low, high in image.convert("RGB").getextrema()):
                            raise RuntimeError(f"Reject blank display: {name}")
                    captured.add(name)
                    print(f"Captured {name}", flush=True)
                if time.monotonic() > deadline:
                    raise TimeoutError("Capture exceeded 15 minutes")
                time.sleep(0.5)
            if process.returncode != 0 or captured != names:
                raise RuntimeError(f"Capture failed; inspect {log_path}")
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=30)
    print("Captured all verified frames. Inspect their appearance before publishing.")


if __name__ == "__main__":
    main()
