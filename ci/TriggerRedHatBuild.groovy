/*
 * Copyright (c) 2020-present Sonatype, Inc. All rights reserved.
 * Includes the third-party code listed at http://links.sonatype.com/products/clm/attributions.
 * "Sonatype" is a trademark of Sonatype, Inc.
 */

/**
 * This script triggers the build service for a certified docker image at Red Hat.
 * It's meant to be used by Jenkins via the Jenkinsfile.
 */
@Grab('io.github.http-builder-ng:http-builder-ng-core:1.0.4')

import groovyx.net.http.HttpBuilder
import groovyx.net.http.HttpException

if (args.size() < 3) {
  System.err.println('Usage: groovy TriggerRedhatBuild.groovy <version> <projectId> <apiKey>')
  System.exit(1)
}

new BuildClient(*args).run()

class BuildClient {
  private static final Integer TIMEOUT_MINUTES = 20

  private final String version
  private final String projectId

  private final HttpBuilder builder

  BuildClient(String version, String projectId, String apiKey) {
    this.version = version
    this.projectId = projectId

    builder = HttpBuilder.configure {
      request.uri = 'https://connect.redhat.com'
      request.headers['Authorization'] = "Bearer ${apiKey}"
      request.contentType = 'application/json'
      request.body = [:]
    }
  }

  /**
   * fire off a series of requests to build and publish
   * a container.
   */
  void run() {
    final nextTag = getNextTag(version)
    println "Triggering build as ${nextTag}"

    final buildStatus = build(nextTag)

    if (buildStatus.status != 'Created') {
      fail(buildStatus)
    }

    final completedBuild = getCompletedBuild(nextTag)

    if (completedBuild.failure) {
      fail(completedBuild.failure)
    }

    final published = publish(completedBuild.digest, completedBuild.name)

    if (published.failure) {
      fail(published.failure)
    }

    println published
  }

  /**
   * calculate the cutoff time in the future in miliseconds
   * for comparison to System.currentTimeMillis()
   * @param start start time in millis
   * @param minutes minutes into the future
   * @return future time in millis
   */
  private Long calcCutoffTime(Long start, Integer minutes) {
    return minutes * 60 * 1000 + start
  }

  /**
  * fail with message and exit with an error code for jenkins to see
  * @param message message to print
  */
  private void fail(String message) {
    System.err.println(message)
    System.exit(1)
  }


  /**
  * Request current version tags available at Red Hat.
  * @return the list of all tags
  */
  private List getTags() {
    return builder.post {
      request.uri.path = "/api/v2/projects/${projectId}/tags"
    }.tags
  }

  /**
  * Request current version tags available at Red Hat,
  * and calculate the next tag to use in this build.
  * @param version the base version we're currently building
  * @return the full new version string to submit for the next build
  */
  private String getNextTag(String version) {
    final tags = getTags()*.name.collectMany {
      it.split(', ').collect()
    }

    final currentIndex = tags.findAll {
      it.startsWith(version)
    }.collect {
      it.replaceAll(/${version}-(\d+)-?.*/, '$1') as Integer
    }.sort().reverse()[0]

    final nextIndex =((currentIndex ?: 0) as Integer) + 1

    return "${version}-${nextIndex}"
  }

  /**
  * Trigger build of the certified image at Red Hat,
  * @param nextTag the full version tag to be assigned to the new build
  * @return the map from json with the status of the submitted build
  */
  private Map build(String nextTag) {
    return builder.post {
      request.uri.path = "/api/v2/projects/${projectId}/build"
      request.body = [tag: nextTag]
    }
  }

  /**
  * Poll for the completed (built and scanned) build at Red Hat build service.
  * @param nextTag the full version tag assigned to the new build
  * @return the map from json with info about the completed build
  */
  private Map getCompletedBuild(String nextTag) {
    final endTime = calcCutoffTime(System.currentTimeMillis(), TIMEOUT_MINUTES)

    while (System.currentTimeMillis() < endTime) {
      println 'Waiting for build to finish.'
      sleep 60000

      try {
        final completedBuild = getTags().find {
          it.name == nextTag && it.scan_status == 'passed'
        }

        if (completedBuild) {
          return completedBuild
        }
      } catch (HttpException ex) {
        ex.printStackTrace()
        System.err.println "Failed retrieving completed builds, but still trying: ${ex.statusCode} [${ex.body}]"
      }
    }

    return [failure: "TIMEOUT waiting for complete build: ${TIMEOUT_MINUTES} minutes"]
  }

  /**
  * Trigger publishing of the new image at Red Hat build service.
  * @param digest hash string that identifies the container to publish
  * @param name tag name (version) of the container image to publish
  * @return the map from json with status of the published container image
  */
  private Map publish(String digest, String name) {
    final publishPath = [
      '/api/v2/projects',
      projectId,
      'containers',
      digest,
      'tags',
      name,
      'publish'
    ].join('/')

    try {
      return builder.post {
        request.uri.path = publishPath
      }
    } catch (HttpException ex) {
      ex.printStackTrace()
      return [failure: "Failed to publish: ${ex.statusCode} [${ex.body}]"]
    }
  }
}
