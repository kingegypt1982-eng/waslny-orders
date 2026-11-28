import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingPropertiesFile = rootProject.file("key.properties")
val signingProperties = Properties().apply {
    if (signingPropertiesFile.isFile) {
        signingPropertiesFile.inputStream().use { load(it) }
    }
}
val requiredSigningProperties = listOf(
    "storeFile",
    "storePassword",
    "keyAlias",
    "keyPassword",
)
val missingSigningProperties = requiredSigningProperties.filter {
    signingProperties.getProperty(it).isNullOrBlank()
}
val releaseStoreFilePath = signingProperties.getProperty("storeFile")?.trim().orEmpty()
val releaseStoreFile = releaseStoreFilePath.takeIf(String::isNotEmpty)?.let(rootProject::file)
val releaseSigningConfigured = signingPropertiesFile.isFile &&
    missingSigningProperties.isEmpty() &&
    releaseStoreFile?.isFile == true

gradle.taskGraph.whenReady {
    val releaseBuildRequested = allTasks.any { task ->
        task.name.equals("assembleRelease", ignoreCase = true) ||
            task.name.equals("packageRelease", ignoreCase = true) ||
            task.name.equals("bundleRelease", ignoreCase = true)
    }
    if (releaseBuildRequested && !releaseSigningConfigured) {
        val reason = when {
            !signingPropertiesFile.isFile ->
                "Missing android/key.properties. Copy android/key.properties.example and set the release signing values."
            missingSigningProperties.isNotEmpty() ->
                "android/key.properties is missing: ${missingSigningProperties.joinToString(", ")}."
            else -> "The storeFile configured in android/key.properties does not exist."
        }
        throw GradleException("Release APK signing is not configured. $reason")
    }
}

android {
    namespace = "com.waslny.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        create("release") {
            if (releaseSigningConfigured) {
                storeFile = releaseStoreFile
                storePassword = signingProperties.getProperty("storePassword")
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.waslny.mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (releaseSigningConfigured) {
                signingConfigs.getByName("release")
            } else {
                null
            }
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
