allprojects {
    repositories {
        google()
        mavenCentral()
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

subprojects {
    val configureAndroid = { proj: Project ->
        val android = proj.extensions.findByName("android")
        if (android != null) {
            val ext = android as? com.android.build.gradle.BaseExtension
            ext?.compileSdkVersion(36)
            ext?.defaultConfig {
                targetSdkVersion(36)
            }
        }
    }
    
    if (project.state.executed) {
        configureAndroid(project)
    } else {
        project.afterEvaluate {
            configureAndroid(this)
        }
    }
}

