import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing details, kept outside the repository.
//
// key.properties and the keystore itself are listed in android/.gitignore:
// anyone holding them can publish an APK that Android accepts as an update to
// this app, so they must never be committed.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKey = keyProperties.getProperty("storeFile") != null

android {
    namespace = "com.zeez3o.zepos"
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
        applicationId = "com.zeez3o.zepos"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseKey) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Falling back keeps `flutter run --release` working on a fresh
                // clone, but a debug key is generated per machine. An APK signed
                // with one cannot update an install signed with another: Android
                // refuses the update, the only way through is to uninstall, and
                // that erases the shop's database and its backups along with it.
                signingConfig = signingConfigs.getByName("debug")
                logger.warn(
                    "\n" +
                    "================================================================\n" +
                    " ZePOS: APK release ditandatangani KUNCI DEBUG.\n" +
                    " Jangan dibagikan ke toko: pembaruan berikutnya akan ditolak\n" +
                    " Android, dan memasang ulang menghapus seluruh data toko.\n" +
                    " Buat android/key.properties lebih dulu.\n" +
                    "================================================================\n"
                )
            }
        }
    }
}

flutter {
    source = "../.."
}
