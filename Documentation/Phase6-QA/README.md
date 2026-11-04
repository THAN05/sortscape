# Phase 6 Store UI QA

Local StoreKitTest screenshot on iPhone SE (3rd generation), iOS 27.0, November 3, 2026. The UUID-isolated player profile purchased 1,000 coins and 10 hint tokens with dialogs disabled. The test then relaunched, applied an assist, undid its move without refunding the token, relaunched again, and verified 1,000 coins and 9 tokens.

Reviewed wallet, success feedback, localized price, purchase disclosure, scroll layout, and rounded controls. No real transaction was made. Native system confirmation sheets, sandbox accounts, and physical-device VoiceOver still require release QA.

local-store-large.png shows the same verified flow on iPhone 18 Pro; localized product prices and both wallet counters remain within safe areas. Full suites passed 61/61 on both devices; final packaging checks passed 54/54.
