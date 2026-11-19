# SaySplit — TestFlight publishing

Pipeline: merge to `main` → `.github/workflows/release.yml` (macos-26,
Xcode 26, unsigned archive → distribution signing at export) → TestFlight.
Same house standard as My Work Spots (proven 2026-11-18).

## Owner gates (Parthey, one-time for this app)

1. Register the bundle ID: developer.apple.com → Certificates, Identifiers
   & Profiles → Identifiers → + → App IDs → App — Description "SaySplit",
   Explicit `com.parthey.saysplit`, no capabilities → Register.
2. Create the app record: App Store Connect → My Apps → + → New App —
   iOS, Name **SaySplit** (if taken, tell Alfred — we pick a variant, the
   bundle ID does not change), English (U.S.), Bundle `com.parthey.saysplit`,
   SKU `saysplit-ios-001`, Full Access.
3. Add the SAME 4 secrets as Work Spots to THIS repo
   (github.com/beastmodepk/SaySplit → Settings → Secrets and variables →
   Actions): `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `ASC_TEAM_ID`
   — same Alfred CI key, same values.
4. After the first upload: App Store Connect → SaySplit → TestFlight →
   clear Missing Compliance (None / no encryption) → add yourself to the
   internal test group.

Until the secrets land, release.yml dry-runs the unsigned build only.
Final App Store Submit / Release always stays Parthey's tap.
