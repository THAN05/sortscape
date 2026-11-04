# StoreKit setup and release checklist

## Catalog

Edit `Sources/SortScape/Resources/StoreProducts.json` to configure identifiers. Keep published identifiers stable after launch. Fulfillment amounts are versioned code contracts; do not silently change already sold bundle contents.

| Placeholder identifier | Type | US reference price | Delivery |
| --- | --- | --- | --- |
| com.sortscape.placeholder.removeads | Non-consumable | $3.99 | Ad-removal entitlement; no ads currently exist |
| com.sortscape.placeholder.coins1000 | Consumable | $2.99 | 1,000 coins per verified transaction |
| com.sortscape.placeholder.hints10 | Consumable | $1.99 | 10 automatic-move hint tokens |
| com.sortscape.placeholder.starter | Non-consumable | $5.99 | Ad-removal access plus 1,500 coins and 20 hints once per local profile |
| com.sortscape.placeholder.moonlit | Non-consumable | $3.99 | Moonlit Lagoon island theme ownership |

Prices above are requested setup references and local test data. The app displays only Product.displayPrice from Apple. App Store Connect regional price schedules/localizations are authoritative. No subscriptions, recurring charges, real transactions, product submissions, or publication were performed.

## Local development

Open SortScape.xcodeproj, select the SortScape Local Store scheme (or SortScape debug run), and run an iPhone simulator. The run scheme selects Sources/SortScape/Resources/SortScape.storekit. Use Xcode Debug > StoreKit > Manage Transactions for local refunds, approvals, and interrupted purchases. No Apple sign-in or paid developer membership is required for local StoreKit testing. Do not sign in if a test asks for an account; verify the local configuration and test-host isolation.

StoreKitTest uses its test-bundle configuration with dialogs disabled and temporary injected saves. XCTest sets SORTSCAPE_DISABLE_STORE_START=1 to prevent the app startup listener from racing test managers. UI tests explicitly enable their store and isolate progress by UUID. Production code ignores UUID save overrides outside Debug.

The release store is disabled by default through SortScapeStoreEnabled. Debug simulator verification accepts only .xcode transactions. Do not enable real storefront operations during local development. The app has no StoreKitTest imports; only test bundles link it. The local .storekit file is bundled only in test targets and excluded from the shipping application.

## Delivery and restoration

Verified transaction -> stable environment/transaction key -> proposed profile containing reward and fulfillment record -> atomic file save -> publish -> Transaction.finish(). Any save failure leaves the transaction unfinished. Startup, foreground, updates, and user-requested restore retry delivery. Pending/cancelled/unverified transactions grant nothing. Duplicate IDs cannot regrant currency after process restart. Non-consumable restore rebuilds ownership; consumables already finished are not restored.

Refund/revocation removes the relevant non-consumable entitlement and disables the premium theme when no longer owned. Starter's claimed-reward marker remains. Already delivered consumables or bundle currency are not clawed back, so balances never become negative. Refunding Remove Ads does not remove ad-removal access independently owned through Starter Bundle, and vice versa.

Every puzzle, restoration decoration, and normal hint remains available without purchases. Paid hint tokens apply a legal move automatically; free hints continue to explain a suggested move. Solver failure, cancellation, pause, or stale board results do not spend tokens. Undoing an applied assist does not refund a token.

## Security boundary and optional server

StoreKit's verified result is the authorization boundary; never grant using an unverified payload or a product ID supplied by UI. No secret signing keys or shared secrets belong in the app. The local Codable profile is sandboxed, not tamper-proof or account-backed. Atomicity/idempotency hold while that profile survives; copying, deleting, rolling back, or modifying local data cannot be secured by a device-only ledger. Finished consumables cannot be reconstructed reliably after reinstall or on another device. Starter rewards are once per local profile, not globally once per Apple Account; rebuilding a lost profile may grant them again from a restored entitlement. The UI explicitly discloses the local-save scope.

For account-wide one-time bundle rewards, cross-device consumable balances, anti-tampering, refund debt, and fraud-resistant recovery, add an authenticated server with a unique (environment, transaction ID) constraint and atomic wallet updates. Validate Apple's signed transaction data via App Store Server APIs, bind appAccountToken to an authenticated player, process App Store Server Notifications V2, and reconcile refund/revocation state. The client then finishes only after durable server acknowledgment. A server is not configured in this phase; do not claim global exactly-once delivery or account recovery.

## Apple configuration still required before release

1. Enroll/select the intended Apple Developer team, register/sign the shipping bundle ID, and verify In-App Purchase capability/provisioning. The generated target explicitly links StoreKit as required for In-App Purchase; no team or provisioning profile was configured.
2. Create the app in App Store Connect and replace placeholder product IDs with final identifiers. Create the two consumables and three non-consumables exactly as above. Keep Family Sharing disabled for Starter Bundle's one-time currency contract; decide sharing policy for other entitlements.
3. Complete Paid Apps agreements, banking/tax information, product availability, localized names/descriptions/prices, review screenshots, and review notes explaining free progression and bundle delivery. Confirm refund behavior and Remove Ads disclosure while no advertising exists.
4. Publish app-specific privacy/support pages and review purchase disclosures/terms; these require product ownership decisions. Apple terms/refund links are currently provided.
5. Test with Sandbox accounts and TestFlight on physical devices: all regional storefront prices, parental approval, restrictions, off-device restore/refund, account switching, interruptions, offline recovery, and reinstall behavior. No sandbox/account test was performed here.
6. Decide whether device-local records meet launch needs or deploy the server above. Enable SortScapeStoreEnabled in project.yml info.properties only in an approved shipping configuration after final IDs and entitlements are verified.
7. Obtain the user's approval before submitting products or publishing the app.

## Primary Apple references

- [Local StoreKit configuration](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode)
- [StoreKitTest sessions](https://developer.apple.com/documentation/storekittest/sktestsession)
- [Current entitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements)
- [Unfinished transactions](https://developer.apple.com/documentation/storekit/transaction/unfinished)

Xcode 27.1 currently translates the StoreKitTest simulated .generic(.userCancelled) error to StoreKitError.unknown. The tests assert safe no-grant failure for that SDK behavior and separately exercise the actual Product.PurchaseResult.userCancelled handler. Other StoreKitTest purchase, approval, restore, verification-failure, and refund paths execute real local StoreKit APIs.

The headless simulator also did not expose a native purchase-confirmation Cancel control with dialogs enabled. That exploratory UI attempt was stopped without account sign-in or a purchase; native system-sheet cancellation remains manual sandbox/device QA. Automated cancellation coverage uses the genuine PurchaseResult.userCancelled handler and confirms simulated cancellation errors grant nothing. End-to-end local purchase UI tests use dialogs disabled.
