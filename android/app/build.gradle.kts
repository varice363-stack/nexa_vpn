import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials live in android/key.properties, which is
// git-ignored and never committed. When the file is absent (fresh clone, CI
// without secrets) the release build falls back to the debug key so local
// `flutter run --release` still works — but such an APK cannot be uploaded
// to Google Play.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.nexavpn.nexa_vpn"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // The Xray runtime ships native .so files that must be extracted at
    // install time; without this the tunnel fails to start on some devices.
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    defaultConfig {
        // Permanent Play Store identity — must never change after the first
        // upload, or the app becomes a different listing.
        applicationId = "com.nexavpn.app"
        // flutter_vless requires 23+; pinned explicitly so a Flutter SDK
        // default can never drop below what the tunnel needs.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Not Play-uploadable. See android/KEYSTORE.md.
                signingConfigs.getByName("debug")
            }
            // Code shrinking is OFF by default: it cannot be verified in this
            // environment, and a broken release build is worse than a larger
            // APK. Rules are ready in proguard-rules.pro — flip both flags to
            // true once you can test `flutter build appbundle --release`.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
