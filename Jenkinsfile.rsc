/*
 * Copyright (c) 2016-present Sonatype, Inc. All rights reserved.
 * Includes the third-party code listed at http://links.sonatype.com/products/nexus/attributions.
 * "Sonatype" is a trademark of Sonatype, Inc.
 */
@Library(['private-pipeline-library', 'jenkins-shared']) _
import com.sonatype.jenkins.pipeline.GitHub
import com.sonatype.jenkins.pipeline.OsTools

def imageId = "sonatype/nexus3"

dockerizedBuildPipeline(
  deployBranch: "jenkins-rsc-deploy",
  buildImageId: imageId,
  setVersion: {
    // sets the version based up on the branch.  This becomes the Docker image tag when pushing from master.
    if (env.BRANCH_NAME == 'master') {
      env['VERSION'] = "rsc-${env.BUILD_NUMBER}"
    } else {
      env['VERSION'] = "rsc-${env.BRANCH_NAME}-${env.BUILD_NUMBER}"
    }
  },
  buildAndTest: {
//      def gemInstallDirectory = getGemInstallDirectory()
//      withEnv(["PATH+GEMS=${gemInstallDirectory}/bin"]) {
//         OsTools.runSafe(this, 'gem install --user-install rspec')
//         OsTools.runSafe(this, 'gem install --user-install serverspec')
//         OsTools.runSafe(this, 'gem install --user-install docker-api')
//         OsTools.runSafe(this, "IMAGE_ID=${imageId}:$VERSION rspec --backtrace spec/Dockerfile_spec.rb")
//      }
  },
  skipVulnerabilityScan: true,
  deploy: {
    currentBuild.displayName = "#${currentBuild.id} ${imageId}:${env.VERSION}"

    withSonatypeDockerRegistry() {
      sh """docker tag $DOCKER_IMAGE_ID ${sonatypeDockerRegistryId()}/${imageId}:$VERSION
            docker push ${sonatypeDockerRegistryId()}/${imageId}:$VERSION
            docker rmi ${sonatypeDockerRegistryId()}/${imageId}:$VERSION"""
    }
  }
)

def getGemInstallDirectory() {
  def content = OsTools.runSafe(this, 'gem env')
  for (line in content.split('\n')) {
    if (line.startsWith('  - USER INSTALLATION DIRECTORY: ')) {
      return line.substring(33)
    }
  }
  error 'Could not determine user gem install directory.'
}
