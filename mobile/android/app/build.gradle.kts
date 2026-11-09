import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Signing comes from key.properties written by CI from GitHub secrets. Never committed.
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "com.orbix.app"
    compileSdk = 35
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    defaultConfig {
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keyProps.containsKey("storeFile")) {
                storeFile = file(keyProps["storeFile"] as String)
                storePassword = keyProps["storePassword"] as String
                keyAlias = keyProps["keyAlias"] as String
                keyPassword = keyProps["keyPassword"] as String
            }
        }
    }

    flavorDimensions += "dist"
    productFlavors {
        create("direct") {
            dimension = "dist"
            applicationId = "com.orbix.app"
            manifestPlaceholders["authScheme"] = "com.orbix.app"
        }
        create("play") {
            dimension = "dist"
            applicationId = "com.orbix.play"
            manifestPlaceholders["authScheme"] = "com.orbix.play"
        }
    }

    buildTypes {
        release {
            signingConfig = if (keyProps.containsKey("storeFile")) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
}

flutter { source = "../.." }
