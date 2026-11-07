plugins {
    id("com.android.application")
    id("com.google.gms.google-services") // Removed 'version' and 'apply false' here
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.it7_lab_act"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.it7_lab_act"
        minSdk = flutter.minSdkVersion // Set explicitly to 21 for Firebase compatibility
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
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
