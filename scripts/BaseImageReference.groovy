/*
 * Copyright (c) 2016-present Sonatype, Inc. All rights reserved.
 * Includes the third-party code listed at http://links.sonatype.com/products/nxrm/attributions.
 * "Sonatype" is a trademark of Sonatype, Inc.
 */
interface BaseImageReference
{
  String getReference()

  String getReference(String registryName)
}

class DefaultBaseImageReference
    implements BaseImageReference
{
  private String baseImage

  private DockerImageHelper dockerImageHelper

  DefaultBaseImageReference(String baseImage, DockerImageHelper dockerImageHelper) {
    this.baseImage = baseImage
    this.dockerImageHelper = dockerImageHelper
  }

  String getReference(String registryName = null) {
    def imageDigest = dockerImageHelper.getImageFirstRepoDigest(baseImage)
    if (imageDigest == null) {
      return baseImage
    }
    return imageDigest
  }
}

class DockerImageHelper
{
  private steps

  DockerImageHelper(steps) {
    this.steps = steps
  }

  def getImageId(baseImage) {
    pullImage(baseImage)
    def dockerImageId = steps.sh(
        script: "docker image inspect ${baseImage} | jq -r '.[0].Id' ",
        returnStdout: true
    ).trim()
    return dockerImageId == "null" ? null : dockerImageId
  }

  def getImageArchitecture(baseImage) {
    pullImage(baseImage)
    def imageArch = steps.sh(
        script: "docker image inspect ${baseImage} | jq -r '.[0].Architecture' ",
        returnStdout: true
    ).trim()
    return imageArch == "null" ? null : imageArch
  }

  def getImageFirstRepoDigest(baseImage) {
    pullImage(baseImage)
    def imageDigest = steps.sh(
        script: "docker image inspect ${baseImage} | jq -r '.[0].RepoDigests[0]'",
        returnStdout: true
    ).trim()
    return imageDigest == "null" ? null : imageDigest
  }

  private def pullImage(baseImage) {
    if (!isPulled(baseImage)) {
      steps.sh("docker pull ${baseImage}")
    }
  }

  private def isPulled(baseImage) {
    def status = steps.sh(
        script: "docker image inspect ${baseImage} 1> /dev/null",
        returnStatus: true
    )
    return status == 0
  }
}

static BaseImageReference build(steps, String baseImage) {
  def dockerHelper = new DockerImageHelper(steps)
  return new DefaultBaseImageReference(baseImage, dockerHelper)
}

return this
