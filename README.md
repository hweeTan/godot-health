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

That builds device and arm64-simulator static libraries, then packs each into an xcframework (`ios-arm64` and a simulator slice). godot-cpp is fetched at commit `2bb1acf6f8ae1ce96ac7b9ba3a10b499c59c49ec` (master on 16 Oct 2026). That commit accepts `api_version=4.7`. The released godot-cpp tags stop at 4.5, so a tag pin cannot build a 4.7 extension. SwiftGodot was not used: its 4.7 binding tracks an unreleased engine commit, which is a poor CI pin.

## Install the APK from Actions

1. Open the **Android debug APK** workflow on the commit you want.
2. Download the `sweatpunk-debug-apk` artifact.
3. It contains `sweatpunk-debug.apk` and `manifest-evidence.txt`.
4. On the phone, enable install from unknown sources, then:

```bash
adb install -r sweatpunk-debug.apk
```

The APK is a debug build, arm64-v8a only, package `dev.sweatpunk.spike`, signed with the godot-ci debug keystore. Health Connect must be installed on the phone (Android 14+ has it in the system; older devices need the Health Connect app). The health permission sheet is the first thing to try.

The iOS workflow uploads `sweatpunk-ios-xcode`. That project is unsigned. It is for the compile check, not for a phone install. The export preset uses team id `0000000000` because Godot refuses to write an Xcode project with a blank team id. Replace it with the Apple Developer team id before any signed or TestFlight build. The Simulator does not need that account. See below.

## Run in iOS Simulator

Apple Silicon, Xcode 27.1, Godot 4.7.2. A paid Apple Developer account is not required. The project renderer is `gl_compatibility` because Godot's iOS Simulator library is built with Metal and Vulkan turned off.

Godot 4.7.2's official `ios.zip` lists an arm64 simulator slice, but `libgodot.a` and `libgodot_camera.a` in that slice are x86_64 only. `tools/ensure_ios_simulator_libgodot.sh` compiles the missing arm64 debug slice from the `4.7.2-stable` tag and lipos it in. The first run builds the engine. Later runs see arm64 already present and skip the compile.

The AdMob v5.1.0 iOS template already ships `poing-godot-admob-ads.debug.xcframework` with an `ios-arm64_x86_64-simulator` library that contains arm64 and x86_64. Headless export downloads it. CI checks the slice with `lipo`.

```bash
python3 -m pip install scons

# Export templates installed by the Godot editor (Export -> Manage Export Templates).
TEMPLATES="$HOME/Library/Application Support/Godot/export_templates/4.7.2.stable"
bash tools/ensure_ios_simulator_libgodot.sh "$TEMPLATES"

bash tools/build_healthkit_ios.sh

GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
"$GODOT" --headless --path . --export-debug "iOS" build/ios/sweatpunk.ipa

# Compile for arm64 Simulator without a signing team.
xcodebuild \
  -project build/ios/sweatpunk.xcodeproj \
  -scheme sweatpunk \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/ios/DerivedDataSim \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  build

# Boot the first available iPhone and install.
DEVICE_ID="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    for device in devices:
        if device.get("isAvailable") and device.get("name", "").startswith("iPhone"):
            print(device["udid"])
            raise SystemExit
sys.exit("no iPhone simulator")
')"
xcrun simctl boot "$DEVICE_ID" || true
open -a Simulator
APP="$(find build/ios/DerivedDataSim -path '*Debug-iphonesimulator*' -name 'sweatpunk.app' -type d | head -n 1)"
xcrun simctl install "$DEVICE_ID" "$APP"
xcrun simctl launch "$DEVICE_ID" dev.sweatpunk.spike
```

Opening `build/ios/sweatpunk.xcodeproj` in Xcode and choosing an iPhone simulator as the run destination is the same compile.

Fake health data, in the Simulator's Health app:

1. Open Health and finish the welcome screens. An Apple ID is not required.
2. Tap Browse, search **Steps**, open Steps, tap **Add Data**, set the date to today, enter a step count, tap Add.
3. Search **Workouts**, open Workouts, tap **Add Data**. Choose Walking or Running, set a start and end today, enter energy if the form asks, tap Add.
4. In Sweatpunk, tap **Request health permission** and allow the types on the sheet, then tap **Refresh steps and workouts**.
5. The debug screen lists today's steps and the workout. Samples added in the Health app are manual entries, so the row is marked manual.

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

GDExtension singleton `HealthKit`. Read types: step count, Apple Exercise Time, active energy, workouts. `HKMetadataKeyWasUserEntered` sets `manual: true`. Active minutes are Apple Exercise Time. The export plugin links `HealthKit.framework`. Usage strings and the HealthKit entitlement are in the iOS export preset. The debug xcframework contains an arm64 device slice and an arm64 simulator slice. HealthKit accepts sample data in the Simulator.

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
| `.github/workflows/ios-export.yml` | every push | macOS export of the Xcode project, an unsigned `iphoneos` compile, and an unsigned arm64 `iphonesimulator` compile. macOS minutes are real; switch this to a nightly schedule after the spike if the bill matters. |
| Play internal / TestFlight | only if the variables above are `true` | Secret check, then a printed fastlane command. The job stops there. |

`barichello/godot-ci:4.7.2` starts each step with `sh` (dash). Dash rejects `set -o pipefail` and the step exits 2 before Godot runs. Both container jobs (Headless tests and Build debug APK) died that way on the first Actions run. The Android workflow sets `defaults.run.shell: bash`. Run [38968304179](https://github.com/hweeTan/godot-health/actions/runs/38968304179) logs `shell: bash --noprofile --norc -e -o pipefail {0}` for those steps, and Headless tests printed `TESTS PASSED`.

## Go / no-go

No physical phone or tablet was available. "Works" means a desktop test or a CI compiler produced the artifact. "Partially" means the code and packaging are in the CI logs and a device still has to run them. Evidence below is from commit `10917b6` (16 Oct 2026).

| Integration | Status | Evidence | Still needs a device |
| --- | --- | --- | --- |
| Guest identity | Works | [Android run 38968304179](https://github.com/hweeTan/godot-health/actions/runs/38968304179), job Headless tests: `TESTS PASSED`. The test creates a UUID, reloads it, and rejects `OS.get_unique_id`. | Account linking waits on Nakama. |
| Nakama login | Prepared, not run | `NakamaSlot` returns `local_guest` when the host is empty and `nakama_unwired` when a host is set. The Nakama SDK is absent from the repo. | A Nakama host, then Apple and Google link tokens. |
| Reading timer | Works | Same headless run: 125 seconds stores as 2 minutes, and a second 60 second session persists 185 seconds. The service also stops on pause and focus-out. | Confirm that stop on a backgrounded phone. |
| Pixel sprite | Works | Same test checks a 64×64 PNG and `default_texture_filter=0`, `scale_mode="integer"`, `snap_2d_transforms_to_pixel=true`, 360×640. Import is lossless with mipmaps off (`art/characters/runner_placeholder.png.import`). The debug `TextureRect` forces nearest. | A glance on the phone at the integer scale. |
| Health Connect | Partially | Same Android run: plugin Gradle `BUILD SUCCESSFUL`, then the app Gradle export with `androidx.health.connect:connect-client:1.1.0` and AGP `8.9.1` (`BUILD SUCCESSFUL`). `aapt dump` of `sweatpunk-debug.apk`: package `dev.sweatpunk.spike`, `sdkVersion` 26, `targetSdkVersion` 36, `compileSdkVersion` 36, abi `arm64-v8a`. Permissions `android.permission.health.READ_STEPS`, `READ_EXERCISE`, `READ_ACTIVE_CALORIES_BURNED`. Meta-data `org.godotengine.plugin.v2.HealthConnect` = `dev.sweatpunk.healthconnect.HealthConnectPlugin`. Activity `HealthConnectPermissionActivity` is in the manifest. | Permission sheet, today's steps, a manual entry versus a watch or phone recording, and a phone with no Health Connect provider. |
| HealthKit | Partially | [iOS run 38968304226](https://github.com/hweeTan/godot-health/actions/runs/38968304226): scheme `sweatpunk`, `** BUILD SUCCEEDED **`. The link line includes `-framework HealthKit`, `-lhealthkit.ios.template_debug`, and `-lgodot-cpp.ios.template_debug.arm64`. The first compile kept the HealthKit entitlement. Team id in the preset is the placeholder `0000000000`. | Authorization dialog, step and workout reads, a sample with Was User Entered, and a signed install. Replace the placeholder team id before signing. |
| AdMob rewarded test ad + UMP | Partially | Plugin v5.1.0. The APK manifest `com.google.android.gms.ads.APPLICATION_ID` is `ca-app-pub-3940256099942544~3347511713`. The Gradle command includes `com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk:1.4.0`. The iOS link line includes `-framework GoogleMobileAds` and `-framework UserMessagingPlatform` (Google Mobile Ads 13.9.0, UMP 3.1.0). | Initialize, load, and show the rewarded test ad, and confirm the UMP form under EEA debug geography. |
| Android debug APK | Works | Run 38968304179 uploaded artifact `sweatpunk-debug-apk` (40,690,375 bytes, not expired). It contains the APK and `manifest-evidence.txt`. | Sideload, then the health and ad rows. |
| iOS unsigned compile | Works | Run 38968304226 uploaded artifact `sweatpunk-ios-xcode` (127,796,739 bytes). `xcodebuild` used `CODE_SIGNING_ALLOWED=NO` and produced `sweatpunk.app/sweatpunk`. | A real team id and a signing setup before TestFlight. |
| Play internal upload | Prepared, off | Job Play internal testing was skipped on run 38968304179 (`ENABLE_PLAY_INTERNAL` is unset). Lane `android internal` is in `fastlane/Fastfile`. When the variable is on, the job checks secrets and prints the fastlane command. | Play Console app, upload key, and a release AAB. This debug APK is the sideload build. |
| TestFlight | Prepared, off | Job TestFlight was skipped on run 38968304226 (`ENABLE_TESTFLIGHT` is unset). Lane `ios beta` is in `fastlane/Fastfile`. | Apple Developer membership, match repo, the HealthKit capability on the App ID, and a real team id. |
