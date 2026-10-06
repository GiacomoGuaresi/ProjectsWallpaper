import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
}

/**
 * La firma della release: in CI dalle variabili d'ambiente (il keystore arriva
 * dal secret ANDROID_KEYSTORE), in locale da keystore.properties (non versionato,
 * stesse chiavi). Senza nessuno dei due la release esce non firmata.
 */
val firma: Map<String, String?> = run {
    val locale = Properties()
    rootProject.file("keystore.properties").takeIf { it.exists() }?.reader()?.use(locale::load)
    listOf("ANDROID_KEYSTORE_FILE", "ANDROID_KEYSTORE_PASSWORD", "ANDROID_KEY_ALIAS", "ANDROID_KEY_PASSWORD")
        .associateWith { System.getenv(it) ?: locale.getProperty(it) }
}

android {
    namespace = "it.giacomoguaresi.projectswallpaper"
    compileSdk = 36

    defaultConfig {
        applicationId = "it.giacomoguaresi.projectswallpaper"
        minSdk = 26
        targetSdk = 36
        versionCode = 3
        versionName = "0.2.0"
    }

    signingConfigs {
        if (firma.values.all { it != null }) {
            create("release") {
                storeFile = rootProject.file(firma.getValue("ANDROID_KEYSTORE_FILE")!!)
                storePassword = firma["ANDROID_KEYSTORE_PASSWORD"]
                keyAlias = firma["ANDROID_KEY_ALIAS"]
                keyPassword = firma["ANDROID_KEY_PASSWORD"]
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
            signingConfig = signingConfigs.findByName("release")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlin {
        jvmToolchain(17)
    }
}

dependencies {
    implementation(libs.core.ktx)
    implementation(libs.work.runtime.ktx)
}
