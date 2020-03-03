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
  println 'Usage: groovy TriggerRedhatBuild.groovy <version> <projectId> <apiKey>'
  return
}

def (version, projectId, apiKey) = args

final HttpBuilder builder = HttpBuilder.configure {
  request.uri = 'https://connect.redhat.com'
  request.headers['Authorization'] = "Bearer ${apiKey}"
  request.contentType = 'application/json'
  request.body = [:]
}

final nextTag = getNextTag(builder, projectId, version)
println "Triggering build as ${nextTag}"

build(builder, projectId, nextTag)

final completedBuild = getCompletedBuild(builder, projectId, nextTag)

println publish(builder, projectId, completedBuild.digest, completedBuild.name)

// END

/**
 * Request current version tags available at Red Hat,
 * and calculate the next tag to use in this build.
 * @param builder the configured http builder to use for requests
 * @param projectId project to query versions
 * @param version the base version we're currently building
 * @return the full new version string to submit for the next build
 */
String getNextTag(HttpBuilder builder, String projectId, String version) {
  final tags = builder.post {
    request.uri.path = "/api/v2/projects/${projectId}/tags"
  }.tags*.name.collectMany {
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
 * @param projectId project to build
 * @param nextTag the full version tag to be assigned to the new build
 * @return the map from json with the status of the submitted build
 */
Map build(HttpBuilder builder, String projectId, String nextTag) {
  return builder.post {
    request.uri.path = "/api/v2/projects/${projectId}/build"
    request.body = [tag: nextTag]
  }
}

/**
 * Poll for the completed (built and scanned) build at Red Hat build service.
 * @param builder the configured http builder to use for requests
 * @param projectId project that is building
 * @param nextTag the full version tag assigned to the new build
 * @return the map from json with info about the completed build
 */
Map getCompletedBuild(HttpBuilder builder, String projectId, String nextTag) {
  while (true) {
    println 'Waiting for build to finish.'
    sleep 60000

    final newTags = builder.post {
      request.uri.path = "/api/v2/projects/${projectId}/tags"
    }.tags

    final completedBuild = newTags.find {
      it.name == nextTag && it.scan_status == 'passed'
    }

    if (completedBuild) {
      return completedBuild
    }
  }
}

/**
 * Trigger publishing of the new image at Red Hat build service.
 * @param builder the configured http builder to use for requests
 * @param projectId project to publish
 * @param digest hash string that identifies the container to publish
 * @param name tag name (version) of the container image to publish
 * @return the map from json with status of the published container image
 */
Map publish(HttpBuilder builder, String projectId, String digest, String name) {
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
