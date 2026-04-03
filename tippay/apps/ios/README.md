# Fliq iOS

Native SwiftUI iOS app foundation for Fliq.

## Generate the Xcode project

```bash
xcodegen generate
```

## Build for simulator

```bash
xcodebuild -project FliqIOS.xcodeproj -scheme FliqIOS -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```
