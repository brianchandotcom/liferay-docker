## About

These images are the base software stack for Liferay bundle Docker images. They contain Alpine Linux as OS, Zulu JDK, tools and scripts to run Liferay products. More information can be found in the Dockerfile at http://github.com/liferay/liferay-docker.

## Tags

For [tags](https://hub.docker.com/r/liferay/base/tags) that follow the format *{version}-{date}*, *version* denotes the version of the image, and *date* denotes the date when the Docker image was made.

[Tags](https://hub.docker.com/r/liferay/base/tags) that follow the format *{version}* always point to the latest tag that follows the format *{version}-{date}*.

The version number is determined based on general semantic versioning principles. Release notes can be find by [searching for the version tags in Liferay's issue tracker system](https://issues.liferay.com/issues/?jql=labels%20in%20(d1.1.0)). The version number consists of 3 parts *{major}-{minor}-{patch}*. Increment happens to the:

 - {major} version when a potential breaking change is made (i.e. previous extension points are not available or work differently)
 - {minor} version when a new functionality is added in a backwards compatible manner
 - {patch} version when backwards compatible bug fixes are made.
