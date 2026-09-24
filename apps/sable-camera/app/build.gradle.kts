plugins {
    id("com.android.application")
}

android {
    namespace = "org.sableos.camera"
    compileSdk = 36

    defaultConfig {
        applicationId = "org.sableos.camera"
        minSdk = 29
        targetSdk = 36
        versionCode = 1
        versionName = "0.1"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
