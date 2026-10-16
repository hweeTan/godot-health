# Sweatpunk

Pixel-art cyberpunk RPG in Godot. Verified real-life activity (steps and workouts) plus an in-app reading timer powers the character. This repository is the weeks 1–2 technical spike: one debug screen and the platform integrations that decide whether Godot can ship the game.

Engine pin: **Godot 4.7.2 stable** (GDScript). Godot 4.8 is still a beta and is not used.

The concept mockup in `concepts/cyber-rpg/main-screen.png` is reference art only. The debug screen is a functional spike, not that layout.

## What the debug screen does

Open the project and run it. The portrait screen is 360×640, stretch mode `viewport`, scale mode `integer`, default texture filter nearest, 2D pixel snap on.

| Control | What it proves |
| --- | --- |
| Health buttons | Asks for read permission, then loads today's steps and the last 7 days of workouts / active minutes. Manual entries are flagged when the platform says so. |
| UMP + rewarded buttons | Google's **test** ad units only, plus the UMP consent form with EEA debug geography. |
| Guest id | A random UUID stored in `user://auth/identity.cfg`. It is not `OS.get_unique_id()`. |
| Reading timer | Start / stop. Daily seconds persist in `user://reading/daily.cfg`. Leaving the app stops the timer. |
| Runner sprite | 64×64 placeholder, drawn at 3× with nearest filtering. |

On a desktop the health plugin is absent. The screen shows a labeled stub (`device_verified: false`) so the UI path is visible. That stub is not a device read.

## Project structure

```
project.godot              Godot 4.7 project
export_presets.cfg         Android (debug APK) and iOS (Xcode project only)
game/debug/                The only scene
services/                  Auth, reading timer, health, ads autoloads
services/nakama_slot.gd    Later call site for nakama-godot. No server in this spike.
core/health_payload.gd     Shared reading of the JSON both native plugins return
art/characters/            Placeholder sprite, imported lossless, no mipmaps
addons/admob/              poingstudios/godot-admob-plugin v5.1.0 (GDScript). Binaries download on headless export.
addons/health_connect/     Editor export plugin. Expects an AAR built from native/
addons/healthkit/          GDExtension manifest. The xcframework is built on the macOS workflow.
native/health_connect/     Kotlin v2 Godot plugin, Health Connect client 1.1.0
native/healthkit/          godot-cpp + Objective-C++ HealthKit reader
tools/                     Sprite generator and native build scripts
.github/workflows/         Android debug APK, iOS unsigned compile
fastlane/Fastfile          Play internal and TestFlight lanes. CI does not call them.
```

`native/` is ignored by the Godot importer (`.gdignore`) so Kotlin and C++ sources are not packed into the game. The Android export plugin adds the built AAR. The iOS export loads the xcframework from `addons/healthkit/bin/`, which CI produces and does not commit.

## Run it

1. Install [Godot 4.7.2 stable](https://github.com/godotengine/godot/releases/tag/4.7.2-stable).
2. Open this folder in the Godot project manager.
3. Press F5. The main scene is `game/debug/debug_screen.tscn`.

Headless tests (guest id, Nakama slot, reading timer, manual-entry flags, pixel settings):

```bash
godot --headless --path . --import
godot --headless --path . res://tests/test_runner.tscn
```

The first command registers `class_name` scripts. A missing HealthKit library on Linux or Windows is expected: that GDExtension is iOS-only. The editor prints an error and continues.

Regenerate the placeholder sprite with `python3 tools/make_placeholder_sprite.py`.

### Android plugin, local

```bash
export ANDROID_HOME="$HOME/android-sdk"   # needs platform 36
bash tools/build_health_connect.sh
```

That writes `addons/health_connect/bin/debug/HealthConnect-debug.aar` and the release twin. Those AARs are gitignored. CI builds them before export.

### iOS plugin, local (macOS)

```bash
python3 -m pip install scons
bash tools/build_healthkit_ios.sh
```

godot-cpp is fetched at commit `2bb1acf6f8ae1ce96ac7b9ba3a10b499c59c49ec` (master on 16 Oct 2026). That commit accepts `api_version=4.7`. The released godot-cpp tags stop at 4.5, so a tag pin cannot build a 4.7 extension. SwiftGodot was not used: its 4.7 binding tracks an unreleased engine commit, which is a poor CI pin.

## Install the APK from Actions

1. Open the **Android debug APK** workflow on the commit you want.
2. Download the `sweatpunk-debug-apk` artifact.
3. It contains `sweatpunk-debug.apk` and `manifest-evidence.txt`.
4. On the phone, enable install from unknown sources, then:

```bash
adb install -r sweatpunk-debug.apk
```

The APK is a debug build, arm64-v8a only, package `dev.sweatpunk.spike`, signed with the godot-ci debug keystore. Health Connect must be installed on the phone (Android 14+ has it in the system; older devices need the Health Connect app). The health permission sheet is the first thing to try.

The iOS workflow uploads `sweatpunk-ios-xcode`. That project is unsigned. It is for the compile check, not for a phone install. The export preset uses team id `0000000000` because Godot refuses to write an Xcode project with a blank team id. Replace it with the Apple Developer team id before any signed or TestFlight build.

## Owner setup

These accounts are not created by the spike. Nothing here is a secret, and no secret belongs in git.

| Account | Why |
| --- | --- |
| Google Play Console (one-time $25) | Later internal-testing uploads. Not required to sideload the debug APK. |
| Apple Developer Program ($99/year) | HealthKit entitlement, signing, TestFlight. Not required for the unsigned compile. |
| AdMob | Replace the Google **test** app ids before any store build. The spike hard-codes Google's published sample ids. |
| Apple Health / Health Connect | No extra dashboard for the read APIs. The phone must have the health store, and the iOS app id needs the HealthKit capability once you sign. |

### Repository variables (both default off)

| Variable | Effect when set to `true` |
| --- | --- |
| `ENABLE_PLAY_INTERNAL` | Lets the Play job check that secrets exist. It still does not upload. See `fastlane/Fastfile` lane `android internal`. |
| `ENABLE_TESTFLIGHT` | Lets the TestFlight job check that secrets exist. It still does not upload. See lane `ios beta`. |

### Secrets to add later

Play internal (`android internal` expects `PLAY_JSON_PATH` and `AAB_PATH` pointing at a **signed release AAB**, not the debug APK):

| Secret | Contents |
| --- | --- |
| `PLAY_SERVICE_ACCOUNT_JSON` | Play Console service-account JSON, the whole file contents. |
| `ANDROID_UPLOAD_KEYSTORE_BASE64` | Upload keystore, base64. |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password. |
| `ANDROID_KEY_ALIAS` | Key alias. |
| `ANDROID_KEY_PASSWORD` | Key password. |

TestFlight:

| Secret | Contents |
| --- | --- |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API key id. |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer id. |
| `APP_STORE_CONNECT_KEY_BASE64` | The `.p8` file, base64. |
| `MATCH_GIT_URL` | Private match certificates repo. |
| `MATCH_PASSWORD` | Match encryption password. |
| `MATCH_DEPLOY_KEY` | Deploy private key that can read the match repo. |

The debug APK workflow needs none of these.

## Integrations

### Health Connect (Android)

Kotlin plugin on the official v2 Godot Android plugin shape (`org.godotengine:godot:4.7.2.stable`). It reads today's steps, 7 days of exercise sessions, and 7 days of active calories. `Metadata.recordingMethod == RECORDING_METHOD_MANUAL_ENTRY` sets `manual: true`. Active minutes are the sum of exercise-session durations. Health Connect has no Apple Exercise Time type; the payload field `active_minutes_source` says so.

Permission UI is a real activity (`HealthConnectPermissionActivity`) with a rationale, then `PermissionController.createRequestPermissionResultContract()`. An activity-alias handles the Android 14 privacy-dashboard rationale intent.

### HealthKit (iOS)

GDExtension singleton `HealthKit`. Read types: step count, Apple Exercise Time, active energy, workouts. `HKMetadataKeyWasUserEntered` sets `manual: true`. Active minutes are Apple Exercise Time. The export plugin links `HealthKit.framework`. Usage strings and the HealthKit entitlement are in the iOS export preset.

If unsigned `xcodebuild` rejects that entitlement, the workflow retries without `CODE_SIGN_ENTITLEMENTS` and says so in the log. A device or TestFlight build has to put the entitlement back and sign with a HealthKit-enabled profile.

### AdMob

[poingstudios/godot-admob-plugin v5.1.0](https://github.com/poingstudios/godot-admob-plugin/releases/tag/v5.1.0) (13 Sep 2026), the plugin named in the plan. It declares support through Godot 4.7.2. The GDScript addon is vendored. Native Android and iOS binaries are not: headless editor startup downloads `android-template-v4.7.2.zip` and `ios-template-v4.7.2.zip`. That download succeeded on the Linux import used for the tests below.

Test app ids and rewarded units are Google's public samples:

| | Android | iOS |
| --- | --- | --- |
| App | `ca-app-pub-3940256099942544~3347511713` | `ca-app-pub-3940256099942544~1458002511` |
| Rewarded | `ca-app-pub-3940256099942544/5224354917` | `ca-app-pub-3940256099942544/1712485313` |

UMP uses `ConsentInformation.update`, then `load_consent_form` when a form is offered, and shows it when status is `REQUIRED`. Debug geography is EEA so a phone is more likely to be asked. No production ad unit is in the project.

### Guest identity

`services/auth_service.gd` writes a UUID v4. `services/nakama_slot.gd` is the later slot for `authenticate_device_async`, `link_apple_async`, and `link_google_async`. With an empty host it returns `local_guest`. With a host set and no SDK, it returns `ok: false` and `nakama_unwired`. It does not pretend a login succeeded.

### CI

| Workflow | When | Result |
| --- | --- | --- |
| `.github/workflows/android-debug.yml` | every push | Headless tests, then a debug APK artifact. |
| `.github/workflows/ios-export.yml` | every push | macOS export of the Xcode project and an unsigned `iphoneos` compile. macOS minutes are real; switch this to a nightly schedule after the spike if the bill matters. |
| Play internal / TestFlight | only if the variables above are `true` | Secret check, then a printed fastlane command. No upload. |

## Go / no-go

No physical phone or tablet was available in this environment. "Works" means a desktop test or a compiler produced the artifact. "Partially" means the code and packaging are in place and a device still has to run them. "Blocked" means the spike could not build that path.

| Integration | Status | Evidence | Still needs a device |
| --- | --- | --- | --- |
| Guest identity | Works | `godot --headless res://tests/test_runner.tscn` printed `TESTS PASSED` on Godot 4.7.2. The test creates a UUID, reloads it, and rejects `OS.get_unique_id`. | Nothing for the spike. Account linking waits on Nakama. |
| Nakama login | Prepared, not run | `NakamaSlot` returns `local_guest` or `nakama_unwired`. The SDK is not vendored. | A Nakama host, then Apple and Google link tokens. |
| Reading timer | Works | Same test run: 125 seconds stores as 2 minutes, a second 60 second session persists 185 seconds. | Confirm the timer stops when the phone is backgrounded. The code listens for pause and focus-out. |
| Pixel sprite | Works | Test checks a 64×64 PNG and the project settings `default_texture_filter=0`, `scale_mode="integer"`, `snap_2d_transforms_to_pixel=true`, 360×640. Import is lossless with mipmaps off (`art/characters/runner_placeholder.png.import`). The debug `TextureRect` forces nearest. | A glance at the phone to confirm the integer scale looks the way you want. |
| Health Connect | Partially | `./gradlew :plugin:assemble` succeeded (debug and release AARs, `HealthConnect-debug.aar`). Permissions, the rationale activity, and the plugin meta-data are in the library manifest. | Permission sheet, today's steps, a manual entry versus a watch/phone recording, and a phone with no Health Connect provider. |
| HealthKit | Partially, until the iOS workflow finishes | GDExtension sources, entitlement, usage strings, and `HealthKit.framework` link are in the export preset and export plugin. The binary is built only on macOS CI. | Authorization dialog, step and workout reads, a sample with Was User Entered, and a signed install. The unsigned job may strip the entitlement; that is a CI compromise, not the device configuration. |
| AdMob rewarded test ad + UMP | Partially | Plugin v5.1.0 is vendored. Headless import downloaded both 4.7.2 platform zips. Test ids are the ones in the table above. | Initialize, load, and show the rewarded test ad. Confirm the UMP form appears under EEA debug geography. Ads need a network and a real mobile build. |
| Android debug APK | See the Actions run | Workflow `.github/workflows/android-debug.yml` builds `sweatpunk-debug-apk`. The manifest dump in that artifact is the packaging evidence for Health Connect and the AdMob app id. | Sideload, then the health and ad rows above. |
| iOS unsigned compile | See the Actions run | Workflow `.github/workflows/ios-export.yml`. | A Mac signing setup before TestFlight. |
| Play internal upload | Prepared, off | `ENABLE_PLAY_INTERNAL` is unset, so the job is skipped. Lane `android internal` is in `fastlane/Fastfile`. | Play Console app, upload key, and a release AAB. The debug APK is not that artifact. |
| TestFlight | Prepared, off | `ENABLE_TESTFLIGHT` is unset. Lane `ios beta` is in `fastlane/Fastfile`. | Apple Developer membership, match repo, and the HealthKit entitlement on the App ID. |

Local checks behind the table:

- Godot 4.7.2.stable.official.ed1daf0bf, headless, `TESTS PASSED`, and the debug scene survived `--quit-after 2`.
- Health Connect Gradle build: `BUILD SUCCESSFUL`, both AARs produced.
- AdMob headless installer logged both template zips extracted.

Update this table from the pull request's Actions logs if either workflow fails. A red iOS job is a blocker to record here, not a silent pass.
