import com.android.build.gradle.LibraryExtension
import groovy.lang.GroovyObject
import org.gradle.kotlin.dsl.configure
import org.gradle.kotlin.dsl.withGroovyBuilder

group = "com.mr.flutter.plugin.filepicker"
version = "1.0-SNAPSHOT"

// Temporary workaround, not a permanent fix. Pinning an older AGP here while
// the consuming app applies a newer one through the `plugins` block is
// generally discouraged, this module didn't declare it until it broke
// `android.newDsl=false` projects with custom root level Gradle
// configuration (#2170). Flutter's own AGP 9 `newDsl` migration is still in
// progress (https://github.com/flutter/flutter/issues/180137); its interim
// compatibility shim doesn't appear to reliably reach plugin modules that
// don't declare their own classpath. Remove this block again once that
// migration lands upstream and `android.newDsl=false` is no longer needed.
buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.5.2")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.4.20")
    }
}

rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

fun GroovyObject.intProperty(name: String): Int {
    val value = getProperty(name)
    return when (value) {
        is Number -> value.toInt()
        is String -> value.toInt()
        else -> error("Property '$name' is not an Int-compatible value: $value")
    }
}

val agpVersion = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION
    .substringBefore('.')
    .toInt()
val builtInKotlinProperty = providers.gradleProperty("android.builtInKotlin").orNull
val isBuiltInKotlinEnabled = agpVersion >= 9 &&
    (builtInKotlinProperty == null || builtInKotlinProperty.toBoolean())
val shouldApplyKotlinAndroidPlugin = agpVersion < 9 || !isBuiltInKotlinEnabled

apply(plugin = "com.android.library")
if (shouldApplyKotlinAndroidPlugin) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

val flutterExtension = extensions.getByName("flutter") as GroovyObject
val flutterCompileSdkVersion = flutterExtension.intProperty("compileSdkVersion")

configure<LibraryExtension> {
    compileSdk = flutterCompileSdkVersion
    namespace = "com.mr.flutter.plugin.filepicker"

    defaultConfig {
        minSdk = 21
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        consumerProguardFiles("proguard-rules.pro")
    }

    lint {
        disable += "InvalidPackage"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    if (shouldApplyKotlinAndroidPlugin) {
        withGroovyBuilder {
            "kotlinOptions" {
                setProperty("jvmTarget", JavaVersion.VERSION_17.toString())
            }
        }
    }
}

dependencies {
    add("implementation", "androidx.core:core:1.19.0")
    add("implementation", "androidx.core:core-ktx:1.19.0")
    add("implementation", "androidx.annotation:annotation:1.10.0")
    add("implementation", "androidx.lifecycle:lifecycle-runtime:2.10.0")
}

