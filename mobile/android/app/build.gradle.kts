plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Google Maps SDK for Android reads its key from the manifest at build time,
// so flutter_dotenv (a runtime-only loader) can't supply it. Read the same
// mobile/.env here instead; a GOOGLE_MAPS_ANDROID_API_KEY environment
// variable (e.g. CI) takes precedence. Never printed or hardcoded.
val mapsAndroidKey: String = System.getenv("GOOGLE_MAPS_ANDROID_API_KEY")
    ?: rootProject.file("../.env").takeIf { it.exists() }
        ?.readLines()
        ?.firstOrNull { it.trim().startsWith("GOOGLE_MAPS_ANDROID_API_KEY=") }
        ?.substringAfter("=")?.trim()?.trim('"', '\'')
    ?: ""

android {
    namespace = "com.example.nagarik"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.nagarik"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["GOOGLE_MAPS_ANDROID_API_KEY"] = mapsAndroidKey
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
