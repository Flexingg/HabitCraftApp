import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load signing properties from android/key.properties (local) or CI env. Never commit the keystore.
val signingProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
fun propOrEnv(name: String, env: String): String? =
    (signingProps.getProperty(name) as String?) ?: System.getenv(env)

android {
    namespace = "com.habitcraft.habitcraft_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.habitcraft.habitcraft_app"
        // Health Connect requires API 26+. Flutter default (21) is too low.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = propOrEnv("keyAlias", "ANDROID_KEY_ALIAS")
            keyPassword = propOrEnv("keyPassword", "ANDROID_KEY_PASSWORD")
            storeFile = file(propOrEnv("storeFile", "ANDROID_KEYSTORE_FILE") ?: "keystore/habitcraft-upload.jks")
            storePassword = propOrEnv("storePassword", "ANDROID_KEYSTORE_PASSWORD")
        }
    }

    buildTypes {
        release {
            // Stable signing -> same signature on every build so the APK UPDATES (not reinstalls).
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
