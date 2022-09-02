/*
 * Copyright (c) 2016-present Sonatype, Inc. All rights reserved.
 * Includes the third-party code listed at http://links.sonatype.com/products/nexus/attributions.
 * "Sonatype" is a trademark of Sonatype, Inc.
 */
@Library(['private-pipeline-library', 'jenkins-shared']) _
import com.sonatype.jenkins.pipeline.GitHub
import com.sonatype.jenkins.pipeline.OsTools

node('ubuntu-zion') {
  def commitId, commitDate, imageId, branch
  def organization = 'sonatype',
      gitHubRepository = 'docker-nexus3',
      credentialsId = 'integrations-github-api',
      imageName = 'sonatype/nexus3',
      archiveName = 'docker-nexus3',
      dockerHubRepository = 'nexus3'
  GitHub gitHub

  try {
    stage('Preparation') {
      deleteDir()
      OsTools.runSafe(this, 'docker system prune -a -f')

      def checkoutDetails = checkout scm

      branch = checkoutDetails.GIT_BRANCH == 'origin/main' ? 'main' : checkoutDetails.GIT_BRANCH
      commitId = checkoutDetails.GIT_COMMIT
      commitDate = OsTools.runSafe(this, "git show -s --format=%cd --date=format:%Y%m%d-%H%M%S ${commitId}")

      OsTools.runSafe(this, 'git config --global user.email sonatype-ci@sonatype.com')
      OsTools.runSafe(this, 'git config --global user.name Sonatype CI')

      def apiToken
      withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: credentialsId,
                        usernameVariable: 'GITHUB_API_USERNAME', passwordVariable: 'GITHUB_API_PASSWORD']]) {
        apiToken = env.GITHUB_API_PASSWORD
      }
      gitHub = new GitHub(this, "${organization}/${gitHubRepository}", apiToken)
    }
    stage('Build') {
      gitHub.statusUpdate commitId, 'pending', 'build', 'Build is running'

      def hash = OsTools.runSafe(this, "docker build --quiet --no-cache --tag ${imageName} .")
      imageId = hash.split(':')[1]

      if (currentBuild.result == 'FAILURE') {
        gitHub.statusUpdate commitId, 'failure', 'build', 'Build failed'
        return
      } else {
        gitHub.statusUpdate commitId, 'success', 'build', 'Build succeeded'
      }
    }
    stage('Test') {
      gitHub.statusUpdate commitId, 'pending', 'test', 'Tests are running'

      def gemInstallDirectory = getGemInstallDirectory()
      withEnv(["PATH+GEMS=${gemInstallDirectory}/bin"]) {
        OsTools.runSafe(this, 'gem install --user-install rspec')
        OsTools.runSafe(this, 'gem install --user-install serverspec')
        OsTools.runSafe(this, 'gem install --user-install docker-api')
        OsTools.runSafe(this, "IMAGE_ID=${imageId} rspec --backtrace spec/Dockerfile_spec.rb")
      }

      if (currentBuild.result == 'FAILURE') {
        gitHub.statusUpdate commitId, 'failure', 'test', 'Tests failed'
        return
      }

      gitHub.statusUpdate commitId, 'success', 'test', 'Tests succeeded'
    }

    stage('Evaluate Policies') {
      runEvaluation({ stage ->
        nexusPolicyEvaluation(
          iqStage: stage,
          iqApplication: 'docker-nexus3',
          iqScanPatterns: [[scanPattern: "container:${imageName}"]],
          failBuildOnNetworkError: true,
        )}, (branch == 'main') ? 'build' : 'develop')
    }

    if (currentBuild.result == 'FAILURE') {
      return
    }

    stage('Archive') {
      dir('build/target') {
        OsTools.runSafe(this, "docker save ${imageName} | gzip > ${archiveName}.tar.gz")
        archiveArtifacts artifacts: "${archiveName}.tar.gz", onlyIfSuccessful: true
      }
    }
  } finally {
    OsTools.runSafe(this, 'docker logout')
    OsTools.runSafe(this, 'docker system prune -a -f')
    OsTools.runSafe(this, 'git clean -f && git reset --hard origin/main')
  }
}

def getGemInstallDirectory() {
  def content = OsTools.runSafe(this, 'gem env')
  for (line in content.split('\n')) {
    if (line.startsWith('  - USER INSTALLATION DIRECTORY: ')) {
      return line.substring(33)
    }
  }
  error 'Could not determine user gem install directory.'
}
