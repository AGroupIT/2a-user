allprojects {
    repositories {
        google()
        mavenCentral()
        // RuStore SDK repository
        maven { url = uri("https://artifactory-external.vkpartner.ru/artifactory/maven") }
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

// Fix for deprecated plugins missing namespace (flutter_app_badger etc.)
// Also force compileSdk >= 34 for all subprojects to fix lStar issue
subprojects {
    plugins.withId("com.android.library") {
        val android = project.extensions.getByName("android") as com.android.build.gradle.LibraryExtension
        if (android.namespace == null || android.namespace!!.isEmpty()) {
            val manifestFile = file("${project.projectDir}/src/main/AndroidManifest.xml")
            if (manifestFile.exists()) {
                val manifestContent = manifestFile.readText()
                val packageMatch = Regex("""package="([^"]+)"""").find(manifestContent)
                if (packageMatch != null) {
                    android.namespace = packageMatch.groupValues[1]
                }
            }
        }
        // Force minimum compileSdk for older plugins
        android.compileSdk = maxOf(android.compileSdk ?: 34, 34)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
