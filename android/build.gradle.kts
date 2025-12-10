import com.android.build.gradle.LibraryExtension
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import java.nio.file.Path

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

val rootProjectPath: Path = rootProject.projectDir.canonicalFile.toPath()

subprojects {
    val projectPath = project.projectDir.canonicalFile.toPath()
    if (projectPath.startsWith(rootProjectPath)) {
        val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
        project.layout.buildDirectory.value(newSubprojectBuildDir)
    }
}

subprojects {
    afterEvaluate {
        if (name == "qr_code_scanner") {
            // Older plugin lacks AGP 8 namespace; set it here to keep builds working.
            extensions.findByType(LibraryExtension::class.java)?.let { extension ->
                if (extension.namespace.isNullOrBlank()) {
                    extension.namespace = "net.touchcapture.qr.flutterqr"
                }
            }

            // Align Kotlin target with the plugin's Java configuration (still 1.8).
            tasks.withType(KotlinCompile::class.java).configureEach {
                kotlinOptions.jvmTarget = "1.8"
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
