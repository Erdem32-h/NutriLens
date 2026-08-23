import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    keyProperties.load(keyPropertiesFile.inputStream())
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(localPropertiesFile.inputStream())
}

android {
    namespace = "com.nutrilensapp.android"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // flutter_local_notifications 22.x refuses to link without core library
    // desugaring — its scheduled-notification path uses java.time on API
    // levels that predate it. Without this the Android build fails outright
    // at :app:checkDebugAarMetadata, which is what it had been doing since
    // the daily meal reminder landed. Java 17 and multiDex are part of the
    // same requirement set, not separate opinions.
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.nutrilensapp.android"
        multiDexEnabled = true
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["ADMOB_APP_ID"] = localProperties.getProperty("ADMOB_APP_ID")
            ?: if (project.hasProperty("ADMOB_APP_ID")) project.property("ADMOB_APP_ID") as String
            else "ca-app-pub-3940256099942544~3347511713"  // Google test ID
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String?
            keyPassword = keyProperties["keyPassword"] as String?
            storeFile = keyProperties["storeFile"]?.let { file(it) }
            storePassword = keyProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = if (keyPropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Pulled in on the plugin's own advice: with desugaring enabled, Flutter
    // apps can crash on Android 12L+ unless WindowManager is on the class
    // path. We are enabling desugaring on an app that is already live, so the
    // documented mitigation ships with it rather than after the first crash
    // report.
    implementation("androidx.window:window:1.4.0")
    implementation("androidx.window:window-java:1.4.0")
}
