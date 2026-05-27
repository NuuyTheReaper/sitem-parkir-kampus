pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    val flutterGradlePlugin = file("$flutterSdkPath/packages/flutter_tools/gradle")
    val localFlutterGradlePlugin = file("flutter-gradle-plugin-cache")
    val sourceStamp = "${flutterGradlePlugin.absolutePath}:${flutterGradlePlugin.resolve("build.gradle.kts").lastModified()}"
    val stampFile = localFlutterGradlePlugin.resolve(".source-stamp")

    if (!localFlutterGradlePlugin.exists() || !stampFile.exists() || stampFile.readText() != sourceStamp) {
        localFlutterGradlePlugin.deleteRecursively()
        flutterGradlePlugin.copyRecursively(localFlutterGradlePlugin, overwrite = true)
        stampFile.writeText(sourceStamp)
    }

    includeBuild(localFlutterGradlePlugin.path)

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
