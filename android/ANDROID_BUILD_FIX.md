# Android build configuration

This project is pinned to Flutter 3.47.5 with the Android toolchain versions used by Flutter 3.47.x:

- Android Gradle Plugin: 8.11.1
- Gradle: 8.14.3
- Kotlin Gradle Plugin: 2.2.20
- Java: 17

The project keeps the legacy Kotlin/AGP DSL compatibility flags:
`android.newDsl=false` and `android.builtInKotlin=false`.

GitHub Actions pins Flutter instead of using the moving `stable` channel so a future Flutter release cannot silently change the Android toolchain requirements.
