# HabitCraft ⛏️

Turn your real-world habits (tracked on your phone) into **in-game Minecraft rewards**.

The app reads your actual **Health Connect** data (steps, distance, calories — nothing leaves your
device except "target met" events), files rewards when you hit the habit targets you define, and shows
your earning history — with an op-gated admin panel and live server console.

## Download

Grab the latest APK from the **[Releases](../../releases)** page and install it on your Android phone
(enable "install unknown apps"). Health Connect requires Android 8+ (API 26) with the
[Health Connect](https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata) app.

> **Updating:** every release is signed with the same key and a higher version code, so new APKs
> **update** the app in place — no reinstall needed. (First move to a signed release build requires
> one manual uninstall/reinstall of any earlier debug APK.)

## Features

| Tab | What it does |
|-----|--------------|
| **Today** | Real Health Connect stats + live progress on your habit incentives, with one-tap auto-claim |
| **Rewards** | Create/edit **in-game reward packages** (coins, items, XP, commands) and the **health incentives** that trigger them (admin) |
| **History** | Your reward ledger straight from the Minecraft server |
| **Console** | Send commands & watch the live server log (admin) |

## Architecture

```
Android (Health Connect) ──► HabitCraft Bridge (:9171) ──► Minecraft server (plugin) ──► Crafty Controller
        (data stays on device)     (FastAPI backend)        (rewards_config.json + queue)
```

The app talks only to the **HabitCraft Bridge** — it never touches the Minecraft server or Crafty
directly. Point the app at your bridge URL + API key in **Settings** (gear icon).

## Build locally

```bash
flutter pub get
flutter build apk --release   # signed with android/key.properties (not committed)
```

### Cutting a release

```bash
./release.sh patch    # bump version, tag vX.Y.Z
./release.sh minor --push   # or push to trigger CI
```

Pushing a `v*` tag triggers **GitHub Actions** ([.github/workflows/build-release.yml](.github/workflows/build-release.yml)),
which builds the signed APK and attaches it to the release automatically.

## Repos in this project

- **HabitCraftBridgeService** — the FastAPI bridge the app calls
- **HabitCraftBridge** (server plugin) — turns reward events into in-game rewards

> Minecraft is a trademark of Mojang/Microsoft. This is an unofficial fan project.
