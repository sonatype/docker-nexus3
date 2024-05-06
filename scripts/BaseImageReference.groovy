/*
 * Copyright (c) 2016-present Sonatype, Inc. All rights reserved.
 * Includes the third-party code listed at http://links.sonatype.com/products/nexus/attributions.
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

class RedHatBaseImageReference
    implements BaseImageReference
{
  final static RED_HAT_REGISTRY = "registry.access.redhat.com"

  private String baseImage

  private DockerImageHelper dockerImageHelper

  private steps

  RedHatBaseImageReference(String baseImage, DockerImageHelper dockerImageHelper, steps) {
    this.baseImage = baseImage
    this.dockerImageHelper = dockerImageHelper
    this.steps = steps
  }

  String getReference(String registryName = RED_HAT_REGISTRY) {
    def repoName = extractRedHatRepoName(baseImage, registryName)
    def dockerImageId = dockerImageHelper.getImageId(baseImage)
    if (repoName == null || dockerImageId == null) {
      return null
    }

    def imageId = getRedHatImageId(dockerImageId)
    def repoId = getRedHatRepoId(repoName, registryName)
    if (imageId == null || repoId == null) {
      def imageDigest = dockerImageHelper.getImageFirstRepoDigest(baseImage)
      return imageDigest
    }

    def imageArch = dockerImageHelper.getImageArchitecture(baseImage)
    if (imageArch != null) {
      return "https://catalog.redhat.com/software/containers/${repoName}/${repoId}?architecture=${imageArch}&image=${imageId}"
    }
    else {
      return "https://catalog.redhat.com/software/containers/${repoName}/${repoId}?image=${imageId}"
    }
  }

  private static extractRedHatRepoName(baseImage, registryName) {
    if (!baseImage.contains(registryName)) {
      return null
    }
    def repositoryRegex = "${registryName}\\/(.*)"
    def repository = (baseImage =~ repositoryRegex)[0][1]
    return repository
  }

  private getRedHatImageId(dockerImageId) {
    def imageSearchUrl =
        "https://catalog.redhat.com/api/containers/v1/images?filter=docker_image_id==\"${dockerImageId}\""
    def imageId = steps.sh(
        script: "curl -s -L ${imageSearchUrl} | jq -r '.data[0]._id' ",
        returnStdout: true
    ).trim()

    return imageId == "null" ? null : imageId
  }

  private getRedHatRepoId(repoName, registryName) {
    def repoSearchUrl =
        "https://catalog.redhat.com/api/containers/v1/repositories/registry/${registryName}/repository/${repoName}"
    def repoId = steps.sh(
        script: "curl -s -L ${repoSearchUrl} | jq -r '._id' ",
        returnStdout: true
    ).trim()

    return repoId == "null" ? null : repoId
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

  if (baseImage.contains(RedHatBaseImageReference.RED_HAT_REGISTRY)) {
    return new RedHatBaseImageReference(baseImage, dockerHelper, steps)
  }
  else {
    return new DefaultBaseImageReference(baseImage, dockerHelper)
  }
}

return this
