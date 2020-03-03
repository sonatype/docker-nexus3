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
  fail('Usage: groovy TriggerRedhatBuild.groovy <version> <projectId> <apiKey>')
}

new BuildClient(version: args[0], projectId: args[1], apiKey: args[2]).run()

class BuildClient {
  String version
  String projectId
  String apiKey
  private static final Integer TIMEOUT_MINUTES = 20

  /**
   * fire off a series of requests to build and publish
   * a container.
   */
  void run() {
    final HttpBuilder builder = HttpBuilder.configure {
      request.uri = 'https://connect.redhat.com'
      request.headers['Authorization'] = "Bearer ${apiKey}"
      request.contentType = 'application/json'
      request.body = [:]
    }

    /* a function for querying all the tags */
    final Closure tagFn = this.&getTags.curry(builder)

    final nextTag = getNextTag(tagFn, version)
    println "Triggering build as ${nextTag}"

    final buildStatus = build(builder, nextTag)

    if (buildStatus.status != 'Created') {
      fail(buildStatus)
    }

    final completedBuild = getCompletedBuild(tagFn, nextTag)

    if (completedBuild.failure) {
      fail(completedBuild.failure)
    }

    final published = publish(builder, completedBuild.digest, completedBuild.name)

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
  * @param builder the configured http builder to use for requests
  * @return the list of all tags
  */
  private List getTags(HttpBuilder builder) {
    return builder.post {
      request.uri.path = "/api/v2/projects/${projectId}/tags"
    }.tags
  }

  /**
  * Request current version tags available at Red Hat,
  * and calculate the next tag to use in this build.
  * @param requestTags a closure that produces a list of all the tags
  * @param version the base version we're currently building
  * @return the full new version string to submit for the next build
  */
  private String getNextTag(Closure requestTags, String version) {
    final tags = requestTags()*.name.collectMany {
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
  * @param builder the configured http builder to use for requests
  * @param nextTag the full version tag to be assigned to the new build
  * @return the map from json with the status of the submitted build
  */
  private Map build(HttpBuilder builder, String nextTag) {
    return builder.post {
      request.uri.path = "/api/v2/projects/${projectId}/build"
      request.body = [tag: nextTag]
    }
  }

  /**
  * Poll for the completed (built and scanned) build at Red Hat build service.
  * @param requestTags a closure that produces a list of all the tags
  * @param nextTag the full version tag assigned to the new build
  * @return the map from json with info about the completed build
  */
  private Map getCompletedBuild(Closure requestTags, String nextTag) {
    final endTime = calcCutoffTime(System.currentTimeMillis(), TIMEOUT_MINUTES)

    while (System.currentTimeMillis() < endTime) {
      println 'Waiting for build to finish.'
      sleep 60000

      final completedBuild = requestTags().find {
        it.name == nextTag && it.scan_status == 'passed'
      }

      if (completedBuild) {
        return completedBuild
      }
    }

    return [failure: "TIMEOUT waiting for complete build: ${TIMEOUT_MINUTES} minutes"]
  }

  /**
  * Trigger publishing of the new image at Red Hat build service.
  * @param builder the configured http builder to use for requests
  * @param digest hash string that identifies the container to publish
  * @param name tag name (version) of the container image to publish
  * @return the map from json with status of the published container image
  */
  private Map publish(HttpBuilder builder, String digest, String name) {
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
