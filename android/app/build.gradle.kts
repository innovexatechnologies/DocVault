plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.doc_vault"

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
        applicationId = "com.example.doc_vault"

        // The Google Code Scanner API (com.google.android.gms:play-services-code-scanner)
        // requires API 23+. flutter.minSdkVersion currently resolves lower than that,
        // so it's pinned here explicitly. This does raise the app's floor to Android 6.0 (Marshmallow)
        // and above -- devices on Android 5.x will no longer be able to install the app.
        minSdk = maxOf(23, flutter.minSdkVersion)

        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig =
                signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")

    // Google Code Scanner API: on-demand barcode/QR scanning delivered entirely
    // through Google Play services. No camera permission is required for this
    // specific API (Play services owns the camera + UI, and only the decoded
    // result is handed back to the app).
    // https://developers.google.com/ml-kit/vision/barcode-scanning/code-scanner
    implementation("com.google.android.gms:play-services-code-scanner:16.1.0")
}

flutter {
    source = "../.."
}
