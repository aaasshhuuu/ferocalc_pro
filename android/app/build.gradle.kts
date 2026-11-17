import java.io.File
import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

val hasValidKeyPropertiesFile = keystorePropertiesFile.exists() && keystorePropertiesFile.isFile
if (hasValidKeyPropertiesFile) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val releaseKeyAlias: String? = keystoreProperties.getProperty("keyAlias")
val releaseKeyPassword: String? = keystoreProperties.getProperty("keyPassword")
val releaseStorePassword: String? = keystoreProperties.getProperty("storePassword")
val releaseStorePath: String? = keystoreProperties.getProperty("storeFile")
val releaseStoreFile: File? = releaseStorePath?.let { rootProject.file(it) }

val hasValidReleaseSigning: Boolean = hasValidKeyPropertiesFile &&
    !releaseKeyAlias.isNullOrBlank() &&
    !releaseKeyPassword.isNullOrBlank() &&
    !releaseStorePassword.isNullOrBlank() &&
    releaseStoreFile != null &&
    releaseStoreFile.exists() &&
    releaseStoreFile.isFile

// Explicit opt-in for Staging QA builds only.
// Debug-signed release artifacts are strictly for staging QA / preview verification
// and are NOT Play Store publishable.
val stagingDebugSigningOptIn: Boolean = System.getenv("FEROCALC_STAGING_DEBUG_SIGNING")
    ?.trim()
    ?.equals("true", ignoreCase = true) == true

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ferocalc.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ferocalc.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasValidReleaseSigning) {
            create("release") {
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
            }
        } else {
            // Unconfigured release signing config without storeFile.
            // When release signing is selected without valid credentials,
            // Gradle fails closed during :app:packageRelease.
            create("release") {
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                storeFile = null
                storePassword = releaseStorePassword
            }
        }
    }

    buildTypes {
        release {
            if (hasValidReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            } else if (stagingDebugSigningOptIn) {
                // STAGING QA ONLY:
                // Debug-signed release artifacts are for staging QA / preview testing only
                // and are NOT Play Store publishable.
                signingConfig = signingConfigs.getByName("debug")
            } else {
                // FAIL-CLOSED DEFAULT:
                // In production release builds without valid release keystore credentials
                // and without explicit FEROCALC_STAGING_DEBUG_SIGNING opt-in, selecting
                // unconfigured release signing causes :app:packageRelease to fail safely.
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = false
            isShrinkResources = false
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
