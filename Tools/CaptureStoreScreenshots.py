#!/usr/bin/env python3
"""Run real simulator flows or export existing XCTest attachments unchanged."""
import argparse
import json
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FLOWS = (
    "ProgressionUITests/testSolveRewardUnlockAndRelaunchPersistence",
    "ProgressionUITests/testAllTenDecorationsCanBeBuiltWithFundedWallet",
    "StoreUITests/testLocalStorePurchasesAndHintInventorySurviveRelaunch",
)
NAMES = {
    "Gameplay": "01-gameplay",
    "Completion": "02-completion",
    "Restored island": "03-restored-island",
    "Home": "qa-only-home",
    "Local store": "qa-only-local-store",
}

parser = argparse.ArgumentParser(description=__doc__)
source = parser.add_mutually_exclusive_group(required=True)
source.add_argument("--result", type=Path)
source.add_argument("--device", help="Installed simulator UUID")
capture = parser.add_mutually_exclusive_group()
capture.add_argument("--omit-store", action="store_true", help="Capture only gameplay, rewards and island")
capture.add_argument("--store-only", action="store_true", help="Export only the local StoreKit QA screen")
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
if args.omit_store:
    FLOWS = FLOWS[:2]
    del NAMES["Local store"]
if args.store_only:
    FLOWS = FLOWS[-1:]
    NAMES = {"Local store": NAMES["Local store"]}
out = args.output.resolve()
out.mkdir(parents=True, exist_ok=True)

with tempfile.TemporaryDirectory(prefix="sortscape-capture-") as directory:
    tmp = Path(directory)
    result = args.result.resolve() if args.result else tmp / "Capture.xcresult"
    if args.device:
        subprocess.run([
            "xcodebuild", "-project", "SortScape.xcodeproj", "-scheme", "SortScape",
            "-destination", f"platform=iOS Simulator,id={args.device}",
            "-derivedDataPath", "DerivedDataPhase10",
            "-clonedSourcePackagesDirPath", ".spm-firebase", "-skipPackageUpdates",
            "-parallel-testing-enabled", "NO", "-resultBundlePath", str(result),
            *(f"-only-testing:SortScapeUITests/{flow}" for flow in FLOWS),
            "test", "CODE_SIGNING_ALLOWED=NO",
        ], cwd=ROOT, check=True)
    exported = tmp / "attachments"
    subprocess.run(["xcrun", "xcresulttool", "export", "attachments",
                    "--path", str(result), "--output-path", str(exported)],
                   check=True, stdout=subprocess.DEVNULL)
    images = {}
    for group in json.loads((exported / "manifest.json").read_text()):
        test = group.get("testIdentifier", "").removesuffix("()")
        if test not in FLOWS:
            continue
        for item in group["attachments"]:
            filename = item["suggestedHumanReadableName"]
            label = filename.split("_", 1)[0]
            if label not in NAMES or not filename.endswith(".png") or item["isAssociatedWithFailure"]:
                continue
            image = exported / item["exportedFileName"]
            with image.open("rb") as file:
                header = file.read(24)
            if header[:8] != b"\x89PNG\r\n\x1a\n":
                raise ValueError(f"Invalid PNG: {image}")
            width, height = struct.unpack(">II", header[16:24])
            destination = out / (NAMES[label] + ".png")
            shutil.copyfile(image, destination)
            images[label] = {
                "file": destination.name, "pixels": [width, height],
                "device": item["deviceName"], "test": test,
                "usage": {"Local store": "QA only; local StoreKit fixture",
                          "Home": "QA only; Debug home may expose the local storefront"}.get(label, "candidate"),
            }
    missing = NAMES.keys() - images.keys()
    if missing:
        raise SystemExit(f"Missing screenshot attachments: {', '.join(sorted(missing))}")
    (out / "manifest.json").write_text(json.dumps({
        "sourceResult": str(result) if args.result else "Dedicated screenshot test run",
        "images": list(images.values()),
    }, indent=2) + "\n")
    print(f"Exported {len(images)} unedited captures to {out}")
