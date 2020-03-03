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
println "Deploying as ${nextTag}"

build(builder, projectId, nextTag)

final completedBuild = getCompletedBuild(builder, projectId, nextTag)

println publish(builder, projectId, completedBuild.digest, completedBuild.name)

// END

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

Map build(HttpBuilder builder, String projectId, String nextTag) {
  return builder.post {
    request.uri.path = "/api/v2/projects/${projectId}/build"
    request.body = [tag: nextTag]
  }
}

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
    }.post()
  } catch (HttpException ex) {
    ex.printStackTrace()
    return [failure: "Failed to publish: ${ex.statusCode} [${ex.body}]"]
  }
}
