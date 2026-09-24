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

        // The Google Code Scanner API requires API 23+.
        // pdfx library works smoothly with minSdk 23+
        minSdk = maxOf(23, flutter.minSdkVersion)

        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Sign with release or debug key
            signingConfig = signingConfigs.getByName("debug")
            
            // NOTE: Keep obfuscation false unless you have explicit ProGuard rules for pdfium / pdfx
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
        jniLibs {
            pickFirsts += "**/libc++_shared.so"
            pickFirsts += "**/libflutter.so"
            pickFirsts += "**/libpdfium.so"
        }
    }
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")

    // Google Code Scanner API
    implementation("com.google.android.gms:play-services-code-scanner:16.1.0")
}

flutter {
    source = "../.."
}

tasks.configureEach {
    if (name.startsWith("cleanMerge") && (name.endsWith("Assets") || name.endsWith("Resources"))) {
        enabled = false
    }
}

tasks.matching { it.name.contains("NativeLibs") || it.name.contains("Assets") }.configureEach {
    doFirst {
        val buildDir = project.layout.buildDirectory.asFile.get()
        if (buildDir.exists()) {
            listOf("intermediates/merged_native_libs", "intermediates/assets").forEach { sub ->
                val dir = File(buildDir, sub)
                if (dir.exists()) {
                    dir.walkBottomUp().forEach { f ->
                        f.setWritable(true)
                    }
                }
            }
        }
    }
}