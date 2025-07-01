plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.jaimevillalba.ravengate"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        // Cambiamos a Java 1.8 y habilitamos el desugaring:
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        // El target de Kotlin debe coincidir con Java 1.8
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.jaimevillalba.ravengate"
        // Firebase Auth 23.2.1 requiere minSdk 23 o superior
        minSdk = 23
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

flutter {
    source = "../.."
}

// ————————————
// Añade este bloque justo aquí:
dependencies {
    // Dependencia estándar de Kotlin
    implementation(kotlin("stdlib-jdk7"))

    // >>> Core-library desugaring para usar APIs de Java 8+ en Android antiguos
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
