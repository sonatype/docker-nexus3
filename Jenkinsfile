/*
 * Copyright (c) 2016-present Sonatype, Inc. All rights reserved.
 * Includes the third-party code listed at http://links.sonatype.com/products/nexus/attributions.
 * "Sonatype" is a trademark of Sonatype, Inc.
 */
@Library('zion-pipeline-library')
import com.sonatype.jenkins.pipeline.GitHub
import com.sonatype.jenkins.pipeline.OsTools

node('ubuntu-zion') {
  def commitId, commitDate, version, gitHubUsername, gitHubRepository, credentialsId, imageName, archiveName
  GitHub gitHub

  try {
    stage('Preparation') {
      gitHubUsername = 'sonatype'
      gitHubRepository = 'docker-nexus3'
      credentialsId = 'integrations-github-api'
      imageName = 'sonatype/nexus3'
      archiveName = 'sonatype-nexus3'

      deleteDir()

      checkout scm

      commitId = OsTools.runSafe(this, 'git rev-parse HEAD')
      commitDate = OsTools.runSafe(this, "git show -s --format=%cd --date=format:%Y%m%d-%H%M%S ${commitId}")

      buildType = scm.branches[0].name != '*/master' ? 'snapshot' : 'release'

      version = readVersion()

      def apiToken
      withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: credentialsId,
                        usernameVariable: 'GITHUB_API_USERNAME', passwordVariable: 'GITHUB_API_PASSWORD']]) {
        apiToken = env.GITHUB_API_PASSWORD
      }
      gitHub = new GitHub(this, "${gitHubUsername}/${gitHubRepository}", apiToken)
    }
    stage('Build') {
      gitHub.statusUpdate commitId, 'pending', 'build', 'Build is running'

      def rubyVersion = OsTools.runSafe(this, 'ls /home/jenkins/.gem/ruby/')
      withEnv(["PATH+GEMS=/home/jenkins/.gem/ruby/${rubyVersion}/bin"]) {
        OsTools.runSafe(this, "docker system prune -a -f")
        OsTools.runSafe(this, "gem install --user-install rspec")
        OsTools.runSafe(this, "gem install --user-install serverspec")
        OsTools.runSafe(this, "gem install --user-install docker-api")
        OsTools.runSafe(this, "rspec --backtrace spec/Dockerfile_spec.rb")
      }

      if (currentBuild.result == 'FAILURE') {
        gitHub.statusUpdate commitId, 'failure', 'build', 'Build failed'
        return
      } else {
        gitHub.statusUpdate commitId, 'success', 'build', 'Build succeeded'
      }
    }
    stage('Archive') {
      dir('build/target') {
        OsTools.runSafe(this, "docker save ${imageName} | gzip > ${archiveName}.tar.gz")
        archiveArtifacts artifacts: "${imageName}.tar.gz", onlyIfSuccessful: true
      }
    }
    if (currentBuild.result == 'FAILURE') {
      return
    }
    if (scm.branches[0].name != '*/master') {
      return
    }
    input 'Push tags?'
    stage('Push tags') {
      withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: credentialsId,
                        usernameVariable: 'GITHUB_API_USERNAME', passwordVariable: 'GITHUB_API_PASSWORD']]) {
        OsTools.runSafe(this, "git tag ${version}")
        OsTools.runSafe(this,
            "git push https://${env.GITHUB_API_USERNAME}:${env.GITHUB_API_PASSWORD}@github.com/${gitHubUsername}/${gitHubRepository}.git ${version}")
      }
      OsTools.runSafe(this, "git tag -d ${version}")
    }
  } finally {
    OsTools.runSafe(this, 'git clean -f && git reset --hard origin/master')
  }
}
def readVersion() {
  def content = readFile 'Dockerfile'
  for (line in content.split('\n')) {
    if (line.startsWith('ARG NEXUS_VERSION=')) {
      return line.substring(18).split('-')[0]
    }
  }
  error 'Could not determine version.'
}
