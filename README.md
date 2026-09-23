> Public sanitized share of the Lohasmeal Flutter WebView shell + coklog host. See `SECURITY_NOTICE.md`. Secrets are placeholders.

# lohasmeal

A new 로하스밀 Flutter project.

## Getting Started

`flutter doctor `

```
Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter (Channel stable, 3.24.5, on macOS 14.3.1 23D60 darwin-arm64, locale en-KR)
[✓] Android toolchain - develop for Android devices (Android SDK version 33.0.1)
[✓] Xcode - develop for iOS and macOS (Xcode 15.4)
[✓] Chrome - develop for the web
[✓] IntelliJ IDEA Ultimate Edition (version 2024.1.1)
[✓] Connected device (5 available)
[✓] Network resources
```

`java --version`

```
openjdk 19.0.2 2023-01-17
OpenJDK Runtime Environment Corretto-19.0.2.7.1 (build 19.0.2+7-FR)
OpenJDK 64-Bit Server VM Corretto-19.0.2.7.1 (build 19.0.2+7-FR, mixed mode, sharing)
```


## Debug Symbols.
cd build/app/intermediates/merged_native_libs/release/mergeReleaseNativeLibs/out/lib
```
zip -r Archive.zip . -x "*.DS_Store"
```