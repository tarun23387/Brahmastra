import java.io.FileInputStream
import java.util.Properties

// Upload key ki jaankari android/key.properties se aati hai.
// Woh file aur .jks keystore git me kabhi commit nahi hote.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val hasReleaseKey = keystorePropertiesFile.exists()

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.brahmastra.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.brahmastra.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // key.properties na ho to yeh config banti hi nahi, aur release
        // build debug key par gir jaati hai (local testing ke liye).
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // appcheck-debug hatane par R8 ki shikayat chup karane wale niyam.
            // proguardFiles jodta hai, badalta nahi — Flutter ke apne niyam
            // jaise the waise hi rehte hain.
            proguardFiles("proguard-rules.pro")

            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("⚠️  android/key.properties nahi mili — release build DEBUG key se sign ho rahi hai. Play Store par yeh upload nahi hogi.")
                signingConfigs.getByName("debug")
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

// firebase_app_check plugin apne build.gradle me firebase-appcheck-debug ko
// `implementation` me daalta hai, `debugImplementation` me nahi — isliye debug
// provider release build me bhi chala jaata tha.
//
// Dart taraf woh kabhi chunta hi nahi (main.dart: kDebugMode ? debug :
// playIntegrity), yaani release me yeh code bekaar padha rehta hai. Bekaar
// code bhejna nahi hai, isliye release ke runtime classpath se hata diya.
// Debug build par koi asar nahi — wahan `flutter run` ko debug provider
// chahiye hota hai aur woh mil jaata hai.
// `configurations.named(...)` yahan nahi chalta — AGP release wali
// configurations script padhe jaane ke *baad* banata hai. Isliye matching +
// configureEach, jo har configuration ke banne par lagti hai.
configurations.matching { it.name.startsWith("release") }.configureEach {
    exclude(group = "com.google.firebase", module = "firebase-appcheck-debug")
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.18.0"))
    implementation("com.google.firebase:firebase-analytics")
}
