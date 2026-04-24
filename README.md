# CalorieCounter

iOS 26 POC for barcode-based nutrition tracking, built in SwiftUI with the Liquid Glass design language. Apple Health sync is planned but currently disabled (requires a paid Apple Developer team); the protocol seams for it still live in `Domain/`.

## Requirements
- Xcode 17+ (ships iOS 26 SDK)
- iPhone running iOS 26 (camera barcode scanning); simulator works for everything except the live scanner (debug-only manual barcode entry is provided)
- A free Apple ID is enough to side-load onto your own device

## Opening the project
`open CalorieCounter.xcodeproj` — the project is checked in as a plain `.xcodeproj` (no XcodeGen/Tuist).

If Xcode asks for a team, pick yours under **Signing & Capabilities** on the `CalorieCounter` target. The camera usage description is already configured in `Info.plist`. No entitlements file is shipped; re-add one when wiring HealthKit back in.

## Running
- **Simulator:** everything runs except live barcode scanning. The Scan tab includes a debug text field to type a barcode and exercise the full lookup → log → dashboard path.
- **Device:** full flow including camera scanning.

## Architecture
Layered, protocol-first, so new features plug in without rewriting core:

- `Domain/` — pure Swift models and service protocols. No SwiftUI, SwiftData, or HealthKit imports.
- `Data/` — concrete implementations: Open Food Facts client, SwiftData persistence, HealthKit wrapper.
- `Features/` — SwiftUI views and `@Observable` view models, one folder per feature.
- `App/` — `@main`, DI container, root TabView.

See [the planning doc](~/.claude/plans/createa-a-swift-project-ios-imperative-kite.md) for full rationale.

## Design language
The UI uses iOS 26 **Liquid Glass** throughout — `.glassEffect()`, `GlassEffectContainer`, `.buttonStyle(.glass)`, and the new translucent `TabView`. Cards, overlays, and the scanner HUD all float on glass.

## Tests
`⌘U` in Xcode, or:

```bash
xcodebuild -project CalorieCounter.xcodeproj -scheme CalorieCounter \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

Covers domain aggregation, Open Food Facts DTO mapping, and SwiftData repository CRUD using an in-memory `ModelContainer`.
