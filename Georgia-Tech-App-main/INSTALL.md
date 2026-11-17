# Installation Guide

How to run the app locally.

## Prerequisites

- macOS with **Xcode 26 or later**. The app targets iOS 26.
- Access to the SGA organization on GT's GitHub (`github.gatech.edu/gt-sga-it`).
- The two config files described below, which are not in git.

## 1. Clone

```bash
git clone https://github.gatech.edu/gt-sga-it/Georgia-Tech-App.git
cd Georgia-Tech-App
```

## 2. Add the config files

Two files hold secrets and are ignored by git. Get them from the tech lead (the team keeps them in a shared Google Drive folder: https://drive.google.com/drive/u/1/folders/1z_jfE3_Kn1UAqHrpqWatioh6NxuuDols) and put both in `Config/`:

| File | What it holds |
|---|---|
| `GoogleService-Info.plist` | Firebase configuration (used for sign-in) |
| `Secrets.plist` | `GTAPI`, the base URL of the GT App API; optional `REPORTEMAIL`, the address the in-app support and "report an issue" actions write to |

`ConfigExample/` shows the shape of both files with placeholder values. Never commit the real ones.

The app will not build or will crash on launch without them.

## 3. Open and run

1. Open `GeorgiaTechApp.xcodeproj`.
2. Pick a simulator (for example iPhone 17 Pro) or a connected device.
3. Press `Cmd + R`.

The first build resolves Swift packages (Firebase), which can take a few minutes.

To run on a physical device, set your own Team and Bundle Identifier under Signing & Capabilities (see [CONTRIBUTING.md](CONTRIBUTING.md)).

## Troubleshooting

- **Build fails on missing files:** check that both plists are in `Config/` and named exactly as above.
- **SwiftLint errors:** the project enforces style with SwiftLint, configured in `.swiftlint.yml`. Run `swiftlint` and fix what it reports. See [CONTRIBUTING.md](CONTRIBUTING.md).
- **Guest sign-in fails with a keychain error:** the build is unsigned. Select a Team in Signing & Capabilities.
- **Data doesn't load:** confirm `GTAPI` in `Secrets.plist` is the current API URL.

Still stuck? Ask the tech lead.
