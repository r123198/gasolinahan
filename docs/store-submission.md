# Store submission guide

What to enter in Google Play Console and App Store Connect for Gasolinahan,
plus the one-time setup steps that can't live in code. Keep this in sync with
`website/public/privacy.html` and `ios/Runner/PrivacyInfo.xcprivacy`: all
three must describe the same data.

- Publisher: Maalam
- Contact: tibudan.rafael@gmail.com
- Package / bundle ID: `com.maalam.gasolinahan`
- Website: https://gasolinahan-e0917.web.app
- Privacy policy: https://gasolinahan-e0917.web.app/privacy
- Account deletion (web): https://gasolinahan-e0917.web.app/delete-account
- Support: https://gasolinahan-e0917.web.app/support

## 1. One-time setup

### Firebase (do first: the app depends on it)

```sh
firebase deploy --only firestore:rules,hosting
```

- The rules let owners delete their points history and reports, which
  account deletion needs. Until they're deployed, Delete account fails.
- In the Firebase console → Storage → Rules, make sure a signed-in user can
  delete `profile_images/{their uid}.jpg`, for example:

  ```
  match /profile_images/{file} {
    allow read: if request.auth != null;
    allow write, delete: if request.auth != null
                         && file == request.auth.uid + '.jpg';
  }
  ```

### Android upload key

```sh
keytool -genkey -v -keystore android/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
cp android/key.properties.example android/key.properties   # then fill in
fvm flutter build appbundle --release
```

- Both files are gitignored. Back them up somewhere safe (a password
  manager): losing the upload key means asking Google to reset it.
- Turn on Play App Signing when you create the app (it's the default).

### iOS

- In App Store Connect, create the app with bundle ID `com.maalam.gasolinahan`.
- Signing team `5VA5T4RDYT` is already set in the Xcode project.
- Build and upload:
  `fvm flutter build ipa --release`, then upload
  `build/ios/ipa/*.ipa` with Transporter or Xcode Organizer.
- The app is iPhone-only and portrait-only. Export compliance is pre-answered
  (`ITSAppUsesNonExemptEncryption = NO`).

### Demo account for reviewers

Both stores need a working login. Create one with the app's normal sign-up,
for example `review@gasolinahan.app`, and add a few fill-ups and a price
report so the screens aren't empty. Don't delete it while a review is open.

## 2. Google Play Console

### Data safety

| Data type | Collected | Shared | Optional | Purpose |
|---|---|---|---|---|
| Location → Precise location | Yes | Yes (OpenStreetMap place and station lookup) | No | App functionality |
| Personal info → Name | Yes | No | No | App functionality, Account management |
| Personal info → Email address | Yes | No | No | App functionality, Account management |
| Personal info → User IDs | Yes | No | No | App functionality, Account management |
| Financial info → Purchase history (fill-up amounts) | Yes | No | Yes | App functionality |
| Photos and videos → Photos (profile photo only) | Yes | No | Yes | App functionality |
| App activity → Other user-generated content (price reports) | Yes | No | Yes | App functionality |

- Encrypted in transit: **Yes** (HTTPS/Firebase).
- Users can request deletion: **Yes**, with the web URL above.
- Not collected, because it stays on the phone: trips and route history,
  physical activity, fill-up photos, scanned price boards and odometers.
- Firebase is a service provider, so data sent to it isn't "sharing".
  OpenStreetMap is listed as shared because coordinates go to its public
  Nominatim/Overpass servers.

### App content

- Privacy policy: the URL above.
- Ads: **No ads**.
- App access: **All or some functionality is restricted** → give the demo
  account.
- Content rating (IARC): no violence, sexuality, gambling or drugs. "Users
  can interact": **No** (price reports update a shared map but there's no
  messaging or profiles). Expect Everyone / PEGI 3.
- Target audience: **18 and over** (drivers). This keeps the app out of the
  Families policy.
- News app / Government app / Financial features / Health: **No**.
- Data deletion: the web URL above.

### Sensitive permissions

**Location permissions → background location declaration.**
Core feature: automatic trip tracking (kilometers and fuel cost per drive)
and fill-up reminders when you stop at a gas station.

Suggested text:

> Gasolinahan records the user's drives in the background so it can count
> kilometers driven and work out fuel cost per kilometer, and reminds the
> user to log a fill-up when they stop at a gas station. The feature is off
> until the user agrees to an in-app disclosure, can be turned off in
> Account → Automatic trip tracking, and recorded trips stay on the device.

Video (30 s, unlisted YouTube link): fresh install → sign in → disclosure
sheet → Turn on → system "Allow all the time" → drive → trip appears in
Trip history → Account toggle off.

**Foreground service.** Type `location`, used by the location plugin to
keep recording an active drive. Same justification and video.

**Activity recognition.** Not a restricted permission; it's covered by the
disclosure.

### Release track

New personal developer accounts must run a **closed test with at least 12
testers for 14 days in a row** before production access unlocks. Start this
early: it's usually the longest wait.

### Store listing assets

- App icon 512×512 PNG
- Feature graphic 1024×500
- 2–8 phone screenshots (1080×1920 or larger)
- Short description (80 chars) and full description

## 3. App Store Connect

### App Privacy ("nutrition label")

Tracking: **No** (no data is used to track people across other companies'
apps or websites).

| Category → type | Linked to user | Used for tracking | Purpose |
|---|---|---|---|
| Contact Info → Name | Yes | No | App Functionality |
| Contact Info → Email Address | Yes | No | App Functionality |
| Identifiers → User ID | Yes | No | App Functionality |
| Location → Precise Location | Yes | No | App Functionality |
| Purchases → Purchase History | Yes | No | App Functionality |
| User Content → Photos or Videos | Yes | No | App Functionality |
| User Content → Other User Content | Yes | No | App Functionality |

These match `ios/Runner/PrivacyInfo.xcprivacy`.

### App Review information

- Sign-in: the demo account.
- Notes (adapt as needed):

> Gasolinahan shows crowdsourced fuel prices in the Philippines and keeps a
> fill-up log. Background location ("Always") is optional and is used only
> for automatic trip tracking: recording the kilometers driven so the app
> can show fuel cost per kilometer, and reminding the user to log a fill-up
> when they stop at a gas station. Users are shown an explanation first and
> can turn it off in Account → Automatic trip tracking; the rest of the app
> works with "While Using" location. Recorded trips stay on the device.
> Account deletion: Account → Delete account.

- Privacy policy URL and support URL: see the top of this file.
- Age rating questionnaire: all "None" → 4+.

### Screenshots

iPhone only: 6.9" display (1320×2868), 3–10 screenshots. Apple scales them
down for smaller iPhones.

## 4. Known risks still open

- **Sign-in to browse (Apple 5.1.1).** Prices can only be read when signed
  in (`firestore.rules`). Apple sometimes rejects apps that require an
  account just to view public information. If that happens: Firebase
  anonymous auth for guests, keeping sign-in for reporting and the fill-up
  log.
- **OpenStreetMap usage policies.** The public tile, Nominatim and Overpass
  servers are fine for a small user base but ban heavy app traffic. Plan a
  different tile source before scaling.
- **Points awarded client-side.** Not a store issue, but anyone could inflate
  their points or edit station prices until awards move to a server.
