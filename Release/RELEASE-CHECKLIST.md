# Clockwork Calc 1.0.0 (6) release candidate

This folder is a preparation package, not evidence of an App Store upload or approval.

## Prepared

- Release version 1.0.0, build 6; existing bundle ID retained.
- UserDefaults required-reason privacy manifest (CA92.1), no tracking or collected
  data declared. About includes the offline/local-storage privacy explanation.
- `ITSAppUsesNonExemptEncryption = NO`: app implements no custom encryption;
  bundled calculation/rendering code runs offline and only OS services are used.
- App Store title, subtitle, keywords, description, promotional text, and review notes.
- Draft support/privacy pages targeting `/fraction-lab/support/` and
  `/fraction-lab/privacy/` on mccainboonma.com. Publish only after the contact address works.
- Reproducible archive helper: `Scripts/archive-release.sh`.
- Third-party notices remain bundled; no GPL ClockworkCalc code is distributed.

## Account and publication steps still required

1. Support email selected by the owner: `Boonmamccain@gmail.com`. No domain
   mailbox was provisioned and no DNS changes were made. A future domain mailbox
   can use `support@mccainboonma.com` after it is configured and tested.
2. Host the prepared support/privacy pages over HTTPS and verify both URLs.
   The October 19 HTTPS probe to mccainboonma.com failed certificate validation
   because its certificate has expired. Renew the certificate or choose a working
   HTTPS host before submission. The source repository is private and is not a
   public support or privacy URL.
3. In Xcode Settings > Accounts, select the paid Apple Developer team. This Mac
   currently exposes an Apple Development identity only; no distribution identity
   or provisioning profile was found. Team membership and cloud signing were not
   verified. Do not infer a Team ID from a certificate's person identifier.
4. Create/check the App Store Connect app record for `com.boonmam.clockworkcalc.ios`.
   Confirm the name is available, seller/copyright identity, pricing, countries,
   agreements, and any applicable business/trader details. Metadata placeholders
   in `app-store-metadata.json` are deliberate unresolved owner choices.
5. Rebuild an archive from the reviewed source with the configured team:
   `TEAM_ID=YOUR_ACTUAL_TEAM_ID Scripts/archive-release.sh`.
   Open the signed archive in Xcode Organizer, Validate App, then Distribute App
   to App Store Connect. Automatic cloud signing may create distribution assets.
   The unsigned archive prepared here cannot be uploaded as-is; no IPA is claimed.
6. Complete privacy answers: app code collects no data; support email is voluntary
   communication outside the app. Review the final hosted support service and
   any subsequently added SDKs before confirming the questionnaire.
7. Complete Apple's current age-rating and accessibility questionnaires honestly.
   No objectionable content, ads, chat, UGC, purchases, or unrestricted browsing
   is implemented. Do not claim accessibility support beyond verified behavior.
8. Enter App Review contact name/phone/email, attach screenshots, and select build.
   Use `review-notes.txt`; no reviewer login credentials are necessary.
9. Test on physical iPhone/iPad and via TestFlight, including offline calculations,
   history, paste/copy, light/dark mode, keyboard, rotation, and larger text.
10. Submit for review and choose manual release. No submission or public release
    has been performed by this preparation step.

## Apple references checked October 19, 2026

- https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest
- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance

The screenshot set uses native 1320 × 2868 iPhone and 2064 × 2752 iPad captures,
converted to JPEG without resizing to satisfy Apple's no-alpha requirement.
