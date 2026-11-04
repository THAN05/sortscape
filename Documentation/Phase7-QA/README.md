# Phase 7 QA — November 3, 2026

- bonus-confirmation-compact.png: explicit saved +25 bonus confirmation, normal completion rewards and reachable Next action. The reward was granted by MockAdService, not an actual watched Google creative.
- pause-controls-compact.png: Resume, Restart and Home stay above settings/privacy text. This fixes a regression found by compact background/resume automation.
- sdk-smoke.json: actual Google/UMP sample-path observation. Test-ad loads failed; no impression, real revenue, or reward was observed. Network-served creative validation remains outstanding.

Full iPhone 18 Pro suite: 80/80 passed. Final compact focused suite: 71/71 passed, including an additional save-retry case added after the full run. Together 81 unique tests were exercised. SwiftPM core: 38/38 passed. Release build passed. No live units or publishing.
