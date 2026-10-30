plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.example"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.example"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Um flavor por adquirente: cada APK leva só a integração da sua (manifest, Kotlin e Dart), porque o
    // PagBank não homologa app com referência a outras adquirentes. O main.dart escolhe a integração
    // Dart pelo flavor, então todo build precisa de --flavor.
    flavorDimensions += "acquirer"
    productFlavors {
        create("stone") {
            dimension = "acquirer"
        }
        create("cielo") {
            dimension = "acquirer"
        }
        create("pagbank") {
            dimension = "acquirer"
            proguardFile("src/pagbank/proguard-rules.pro")
        }
        create("vero") {
            dimension = "acquirer"
            proguardFile("src/genericPrinter/proguard-rules.pro")
        }
        create("rede") {
            dimension = "acquirer"
            // O SDK da Rede (L400) exige a API 28, como o flavor redeSdk do centralizer.
            minSdk = 28
            proguardFile("src/rede/proguard-rules.pro")
        }
        create("sipag") {
            dimension = "acquirer"
            proguardFile("src/genericPrinter/proguard-rules.pro")
            proguardFile("src/sipag/proguard-rules.pro")
        }
    }

    // Driver genérico de impressão (posmpapi), o mesmo do centralizer. Entra só nos flavors das adquirentes
    // que o usam: o AAR cita outras adquirentes, e o PagBank não homologa app com essas referências.
    sourceSets {
        getByName("vero") {
            java.srcDir("src/genericPrinter/kotlin")
        }
        getByName("sipag") {
            java.srcDir("src/genericPrinter/kotlin")
        }
    }

    // O Robolectric só enxerga os recursos do app, como o scheme de retorno do strings.xml, com esta opção. Os
    // testes que montam a integração inteira dependem dela.
    testOptions {
        unitTests.isIncludeAndroidResources = true
    }
}

flutter {
    source = "../.."
}

dependencies {
    // PagBank: SDK dos terminais Smart. O POM não declara dependências, então o RxJava 2 que as funções
    // async* do wrapper usam não vem junto: chame as funções síncronas fora da main thread, como no demo
    // oficial (SmartCoffee), ou adicione o RxJava 2 e o RxAndroid 2 antes de usar as async*.
    "pagbankImplementation"("br.com.uol.pagseguro.plugpagservice.wrapper:wrapper:1.35.0")

    // Vero: driver genérico de impressão (posmpapi, da Execução), copiado do centralizer.
    "veroImplementation"(files("libs/posmpapi_1.01.10-partnersRelease.aar"))
    // O posmpapi chama a biblioteca de impressão da Sunmi no P2 sem trazê-la no AAR. No PDV Varejo ela vinha do
    // plugin vero_flutter, nesta mesma versão; sem ela, a impressão lança NoClassDefFoundError no terminal.
    "veroImplementation"("com.sunmi:printerlibrary:1.0.23")

    // Rede: SDK SmartRede do L400, copiado do plugin flutter_rede_sdk do centralizer.
    "redeImplementation"(files("libs/smartrede-sdk-l400-4.1.1.release.aar"))
    // O SDK da Rede usa estas bibliotecas sem trazê-las no AAR: o Gson lê o pagamento que volta do app da
    // Rede, e a impressora do L400 roda em runBlocking (coroutines). No PDV Varejo elas vinham de outros
    // plugins (o Gson, do flutter_rede_sdk, nesta versão). Sem elas, o pagamento e a impressão lançam
    // NoClassDefFoundError, como aconteceu com a biblioteca da Sunmi na Vero.
    "redeImplementation"("com.google.code.gson:gson:2.11.0")
    "redeImplementation"("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    "redeImplementation"("androidx.appcompat:appcompat:1.7.0")

    // Sipag: apix990 (DX8000 e X990, pelo app Sicoob) e pos7api (P2, pelo app da Ger7), copiados do plugin
    // flutter_sipag_sdk do centralizer. Do pos7api vai só o release: o AAR debug tem o mesmo código, e o plugin
    // os trocava pelo buildType à toa.
    "sipagImplementation"(files("libs/apix990-release.aar"))
    "sipagImplementation"(files("libs/pos7api-release-v1090004.aar"))
    // A Sipag imprime pelo driver genérico, como a Vero, e no P2 ele usa a biblioteca da Sunmi sem trazê-la.
    "sipagImplementation"(files("libs/posmpapi_1.01.10-partnersRelease.aar"))
    "sipagImplementation"("com.sunmi:printerlibrary:1.0.23")
    // O apix990 lê o resultado do app Sicoob em coroutines (Dispatchers.IO, launch, delay) sem trazê-las. No PDV
    // Varejo elas vinham do próprio plugin; aqui o app já as resolve por outro caminho, mas a dependência fica
    // declarada para não sumir com uma atualização, a mesma armadilha da Rede.
    "sipagImplementation"("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.16.1")
}
