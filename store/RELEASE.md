# Releasing Clockwork Calc to Google Play

## One-time: upload key

```sh
zsh tool/create_upload_key.sh
```

This creates:

- `~/clockworkcalc-upload-keystore.jks`: the upload key
- `android/key.properties`: tells the build where the key is and what its password is

**Back up the `.jks` file and its password** (password manager, encrypted
backup). Never commit or share either file; both are git-ignored.

If the upload key is lost, Play Console → Setup → App signing → "Request
upload key reset" lets you register a new one. Google holds the real app
signing key (Play App Signing), so the app itself is never at risk.

## Each release

1. Bump the version in `pubspec.yaml`: `version: 1.0.1+2`
   - `1.0.1` is what users see.
   - `+2` is the build number, which **must increase on every upload**.
2. Build:
   ```sh
   flutter build appbundle
   ```
   Check it's signed with your upload key, not the debug key:
   ```sh
   "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" \
     -printcert -jarfile build/app/outputs/bundle/release/app-release.aab | grep Owner
   ```
   It should show the name you entered when creating the key. `CN=Android Debug`
   means `android/key.properties` is missing on this machine, and Play Console
   will reject that bundle.
3. Upload `build/app/outputs/bundle/release/app-release.aab` in Play Console
   (Testing → Closed testing for the first rounds, Production later).

## Store assets

See `store/listing.md`. Regenerate screenshots after UI changes:

```sh
flutter test tool/store/screenshots_test.dart
```
