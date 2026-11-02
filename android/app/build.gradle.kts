plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.compras"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // exigido pelo flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.compras"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Chave fixa (vem dos secrets do GitHub): sem ela cada build no CI sai com
    // uma chave diferente e o Android recusa atualizar por cima do app instalado.
    val ks = System.getenv("KEYSTORE_PATH")
    signingConfigs {
        create("release") {
            if (ks != null) {
                storeFile = file(ks)
                storePassword = System.getenv("KEYSTORE_PASSWORD")
                keyAlias = System.getenv("KEY_ALIAS")
                keyPassword = System.getenv("KEYSTORE_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (ks != null) "release" else "debug")
        }
    }
}

// Release local sem a chave oficial sai com a de debug: serve para testar,
// mas não instala por cima do app oficial. Avisa para não ser distribuído.
gradle.taskGraph.whenReady {
    val release = allTasks.any {
        it.name.endsWith("Release") &&
            (it.name.startsWith("assemble") || it.name.startsWith("bundle"))
    }
    if (release && System.getenv("KEYSTORE_PATH") == null) {
        logger.warn(
            "\nATENÇÃO: build release SEM a chave oficial (KEYSTORE_PATH vazio).\n" +
                "Este APK usa a chave de debug e NÃO atualiza o app instalado. " +
                "Não distribua.\n"
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // FileProvider do instalador (MainActivity.kt)
    implementation("androidx.core:core:1.13.1")
}
