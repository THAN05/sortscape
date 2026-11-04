# Store screenshot candidates

Real simulator PNGs exported unchanged from XCTest. The capture flows start with
UUID-isolated saves. The island scene uses the completed campaign QA fixture and
the real restoration UI; it does not edit pixels or imply the island starts built.

Run a capture for each installed device (UUID from `xcrun simctl list devices`):

```sh
python3 Tools/CaptureStoreScreenshots.py --device SIMULATOR_UUID \
  --output Documentation/AppStoreScreenshots/DEVICE
```

Or export from a completed full run with `--result PATH.xcresult`. Run StoreKit
capture sessions sequentially. The per-device manifest records original dimensions,
test and device. Only use images whose slots App Store Connect accepts. The large iPhone set is 1320 × 2868; the iPad set is 2064 × 2752. Compact
SE sets are QA references; it is not a substitute for large iPhone or
13-inch iPad screenshots. Check Apple’s [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
again before upload, including future device requirements.

| Order | Screen | Suggested optional caption |
| --- | --- | --- |
| 1 | Live sorting board | Sort at your own pace |
| 2 | Completed world and rewards | Solve a world. Earn rewards. |
| 3 | Restored island | Bring your island to life |

**Do not submit qa-only-local-store.png or qa-only-home.png.** The Debug home may expose the local storefront. It shows the real local StoreKit
test screen and does not match the purchase-off candidate. Do not publish
test prices, debug controls, or permission prompts. Home alone is not enough
to show app use. Review completion and island framing on each size; no
rescaling or fabricated boards. A designer can optionally add accessible,
localized caption overlays and review crop/legibility using a design tool.
Original unedited captures stay in the handoff.


- `iphone-large`: current iPhone 18 Pro Max capture, 2/2 UI flows passed.
- `ipad-13-inch`: current 13-inch iPad Pro capture, 2/2 UI flows passed.
- `iphone-compact`: current compact layout reference. `compact-qa` is historical.
- `store-qa`: current iPhone 18 Pro local StoreKit QA capture; exclude from listing.

Submit only the three numbered images from each approved target set. If the
submission occurs after Apple adds device slots, reconfirm requirements; its
current specification lists iPhone Duo requirements starting April 2027 for
apps using the iOS 27.1 SDK or later.
