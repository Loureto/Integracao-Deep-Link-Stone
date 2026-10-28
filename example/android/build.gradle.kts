allprojects {
    repositories {
        google()
        mavenCentral()

        // PagBank: o PlugPagServiceWrapper só é publicado neste repositório Maven, hospedado no GitHub da
        // PagSeguro. O exclusiveContent busca nele apenas o grupo do wrapper, e o wrapper apenas nele.
        exclusiveContent {
            forRepository {
                maven("https://github.com/pagseguro/PlugPagServiceWrapper/raw/master")
            }
            filter {
                includeGroup("br.com.uol.pagseguro.plugpagservice.wrapper")
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
