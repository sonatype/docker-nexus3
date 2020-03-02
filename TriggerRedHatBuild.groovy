/*
 * Copyright (c) 2020-present Sonatype, Inc. All rights reserved.
 * Includes the third-party code listed at http://links.sonatype.com/products/clm/attributions.
 * "Sonatype" is a trademark of Sonatype, Inc.
 */
@Grab('io.github.http-builder-ng:http-builder-ng-core:1.0.4')

import groovyx.net.http.HttpBuilder
import groovyx.net.http.HttpException

if (args.size() < 3) {
  println 'Usage: groovy TriggerRedhatBuild.groovy <version> <projectId> <apiKey>'
  return
}

def (version, projectId, apiKey) = args

final nextTag = getNextTag(apiKey, projectId, version)
println "Deploying as ${nextTag}"

build(apiKey, projectId, nextTag)

final completedBuild = getCompletedBuild(apiKey, projectId, nextTag)

println publish(apiKey, projectId, completedBuild.digest, completedBuild.name)

String getNextTag(String apiKey, String projectId, String version) {
  final tags = HttpBuilder.configure {
    request.uri = "https://connect.redhat.com/api/v2/projects/${projectId}/tags"
    request.headers['Authorization'] = "Bearer ${apiKey}"
    request.contentType = 'application/json'
    request.body = [:]
  }.post().tags*.name.collectMany {
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

Map build(String apiKey, String projectId, String nextTag) {
  return HttpBuilder.configure {
    request.uri = "https://connect.redhat.com/api/v2/projects/${projectId}/build"
    request.headers['Authorization'] = "Bearer ${apiKey}"
    request.contentType = 'application/json'
    request.body = [tag: nextTag]
  }.post()
}

Map getCompletedBuild(String apiKey, String projectId, String nextTag) {
  while (true) {
    println "Waiting for build to finish."
    sleep 60000

    final newTags = HttpBuilder.configure {
      request.uri = "https://connect.redhat.com/api/v2/projects/${projectId}/tags"
      request.headers['Authorization'] = "Bearer ${apiKey}"
      request.contentType = 'application/json'
      request.body = [:]
    }.post().tags

    final completedBuild = newTags.find {
      it.name == nextTag && it.scan_status == 'passed'
    }

    if (completedBuild) {
      return completedBuild
    }
  }
}

Map publish(String apiKey, String projectId, String digest, String name) {
  final publishUri = [
    "https://connect.redhat.com/api/v2/projects",
    projectId,
    "containers",
    digest,
    "tags",
    name,
    "publish"
  ].join('/')

  try {
    return HttpBuilder.configure {
      request.uri = publishUri
      request.headers['Authorization'] = "Bearer ${apiKey}"
      request.contentType = 'application/json'
      request.body = [:]
    }.post()
  } catch (HttpException ex) {
    ex.printStackTrace()
    return [failure: "Failed to publish: ${ex.statusCode} [${ex.body}]"]
  }
}
