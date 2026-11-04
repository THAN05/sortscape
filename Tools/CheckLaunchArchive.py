#!/usr/bin/env python3
"""Read-only packaging checks for the ads-off, purchases-off candidate."""
import argparse
from pathlib import Path
import plistlib
from urllib.parse import urlsplit

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("archive", type=Path)
parser.add_argument("--submission-preflight", action="store_true",
                    help="Also require a signed archive and an in-app policy URL")
args = parser.parse_args()

def plist(path):
    with path.open("rb") as stream:
        return plistlib.load(stream)

archive = plist(args.archive / "Info.plist")["ApplicationProperties"]
app = args.archive / "Products" / archive["ApplicationPath"]
info = plist(app / "Info.plist")
checks = [
    (info.get("CFBundleIdentifier") == "com.sortscape.puzzleworlds", "unexpected bundle ID"),
    (info.get("CFBundleSupportedPlatforms") == ["iPhoneOS"], "not an iOS device app"),
    (info.get("SortScapeAdsEnabled") == "NO", "ads not disabled"),
    (info.get("SortScapeStoreEnabled") is False, "purchases not disabled"),
    (info.get("SortScapeTelemetryEnvironment") == "Production", "non-production telemetry environment"),
    (info.get("FIREBASE_ANALYTICS_COLLECTION_ENABLED") is False, "analytics on by default"),
    (info.get("FirebaseCrashlyticsCollectionEnabled") is False, "crash reporting on by default"),
    ((app / "PrivacyInfo.xcprivacy").is_file(), "app privacy manifest missing"),
    ((args.archive / "dSYMs" / "SortScape.app.dSYM").is_dir(), "app dSYM missing"),
]
for filename in ("StoreProducts.json", "*.storekit", "GoogleService-Info-Development.plist"):
    checks.append((not any(app.rglob(filename)), f"development resource packaged: {filename}"))
binary = (app / info["CFBundleExecutable"]).read_bytes()
for marker in (b"/1712485313", b"/4411468910", b"com.sortscape.placeholder.",
               b"SortScape development crash probe"):
    checks.append((marker not in binary, f"development marker in app executable: {marker.decode()}"))

if args.submission_preflight:
    url = urlsplit(info.get("SortScapePrivacyPolicyURL", ""))
    checks += [
        (url.scheme == "https" and bool(url.hostname), "approved HTTPS policy URL missing"),
        (bool(archive.get("Team")) and bool(archive.get("SigningIdentity")),
         "archive has no signing identity/team"),
    ]
errors = [message for passed, message in checks if not passed]
print(f"{info['CFBundleIdentifier']} {info['CFBundleShortVersionString']} ({info['CFBundleVersion']})")
if errors:
    for message in errors:
        print(f"FAIL: {message}")
    raise SystemExit(1)
print("Local packaging checks passed. This does not establish App Store acceptance.")
