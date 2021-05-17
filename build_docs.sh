#!/bin/bash

function generate_docker_hub_base_image_page {
		mkdir -p docs/docker_hub

	(
		cat << EOF
## About

These images are the base software stack for Liferay bundle Docker images. They contain Alpine Linux as OS, Zulu JDK, tools and scripts to run Liferay products. More information can be found in the Dockerfile at http://github.com/liferay/liferay-docker.

## Tags

For [tags](https://hub.docker.com/r/liferay/base/tags) that follow the format *{version}-{date}*, *version* denotes the version of the image, and *date* denotes the date when the Docker image was made.

[Tags](https://hub.docker.com/r/liferay/base/tags) that follow the format *{version}* always point to the latest tag that follows the format *{version}-{date}*.

The version number is determined based on general semantic versioning principles. Release notes can be find by [searching for the version tags in Liferay's issue tracker system](https://issues.liferay.com/issues/?jql=labels%20in%20(d1.1.0)). The version number consists of 3 parts *{major}-{minor}-{patch}*. Increment happens to the:

 - {major} version when a potential breaking change is made (i.e. previous extension points are not available or work differently)
 - {minor} version when a new functionality is added in a backwards compatible manner
 - {patch} version when backwards compatible bug fixes are made.
EOF
	) > docs/docker_hub/README-base.md

}

#
# Usage: generate_docker_hub_page image-name product-name example-version-number enterprise?
#
function generate_docker_hub_bundle_image_page {
	mkdir -p docs/docker_hub

	(
		cat << EOF
## Tags

For [tags](https://hub.docker.com/r/liferay/${1}/tags) that follow the format *{version}-d{docker-version}-{date}*, *version* denotes the version of Liferay ${2}, *docker-version* denotes the version of the [parent (\`liferay/base\`) image](https://hub.docker.com/r/liferay/base), and *date* denotes the date when the Docker image was made.

[Tags](https://hub.docker.com/r/liferay/${1}/tags) that follow the format *{version}* always point to the latest tag that follows the format *{version}-d{docker-version}-{date}*.

EOF

		if ( $(${4}) )
		then
			echo "The ${2} images come with a 90 day trial license. Older images will be regularly deleted and new images with a new 90 day trial license will be made available."
		else
			echo "New Docker images will be made even for older releases of Liferay Commerce as our support for Docker evolves."
		fi

		cat << EOF


## Running

To start Liferay ${2}, replace {tag} and execute:

\`docker run -it -p 8080:8080 liferay/${1}:{tag}\`

For example:

\`docker run -it -p 8080:8080 liferay/${1}:${3}\`

The \`-it\` argument allows you to stop the container with CTRL-C. Otherwise, you have to use \`docker kill {containerId}\` to stop the container.

The \`-p 8080:8080\` argument maps the container's port 8080 with the host's port 8080 so that you can access Liferay ${2} from a browser.

## Environment Variables

You can tune the default JVM parameters by setting the environment variable \`LIFERAY_JVM_OPTS\`.

You can customize the behavior of Liferay ${2} via environment variables that map to portal.properties. For example, if you want to provide only English and Portuguese, you could create a portal-ext.properties with the entry:

\`locales.enabled=en_US,pt_BR\`

Or, you could set the environment variable:

\`LIFERAY_LOCALES_PERIOD_ENABLED=en_US,pt_BR\`

Each property's respective environment variable is documented in [portal.properties](https://github.com/liferay/liferay-portal/blob/master/portal-impl/src/portal.properties). Search for the text \`Env:\`.

Environment variables take precedence over portal.properties.

## File System

Docker containers are transient. Whenever you reboot a container, all changes on its file system are lost.

To quickly test changes without building a new image, map the host's file system to the container's file system.

Start the container with the option \`-v \$(pwd)/xyz123:/mnt/liferay\` to bridge \`\$(pwd)/xyz123\` in the host operating system to \`/mnt/liferay\` on the container.

Files in the host directory \`\$(pwd)/xyz123/files\` are also available in the container directory \`/mnt/liferay/files\` and will be copied to \`/opt/liferay\` before Liferay ${2} starts.

For example, if you want to modify Tomcat's setenv.sh file, then place your changes in \`\$(pwd)/xyz123/files/tomcat/bin/setenv.sh\` and setenv.sh will be overwritten in \`/opt/liferay/tomcat/bin/setenv.sh\` before Liferay ${2} starts.

## Scripts

All scripts in the container directory \`/mnt/liferay/scripts\` will be executed before before Liferay ${2} starts. Place your scripts in \`\$(pwd)/xyz123/scripts\`.

## Deploy

Copy files to \`\$(pwd)/xyz123/deploy\` on the host operating system to deploy modules to Liferay ${2} at runtime.

## About

Images are built based off of OpenJDK on Alpine. More information can be found in the Dockerfile at http://github.com/liferay/liferay-docker.

EOF
		if ( $(${4}) )
		then
			cat << EOF
## License

View [license information](https://web.liferay.com/c/portal/register_trial_license?eula=evaluation-license-agreement) for the software contained in this image.

As with all Docker images, these likely also contain other software which may be under other licenses (such as Bash, etc from the base distribution, along with any direct or indirect dependencies of the primary software being contained).

As for any pre-built image usage, it is the image user's responsibility to ensure that any use of this image complies with any relevant licenses for all software contained within.
EOF
		else
			cat << EOF
## License

This library, *Liferay ${2} Community Edition*, is free software ("Licensed Software"); you can redistribute it and/or modify it under the terms of the [GNU Lesser General Public License](http://www.gnu.org/licenses/lgpl-2.1.html) as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; including but not limited to, the implied warranty of MERCHANTABILITY, NONINFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. See the [GNU Lesser General Public License](http://www.gnu.org/licenses/lgpl-2.1.html) for more details.

You should have received a copy of the [GNU Lesser General Public License](http://www.gnu.org/licenses/lgpl-2.1.html) along with this library; if not, write to

Free Software Foundation, Inc.
51 Franklin Street, Fifth Floor
Boston, MA 02110-1301 USA
EOF
		fi
	) > docs/docker_hub/README-${1}.md
}

function main {
	generate_docker_hub_base_image_page

	generate_docker_hub_bundle_image_page dxp DXP 7.3.10-ga1 true

	generate_docker_hub_bundle_image_page commerce Commerce 2.0.7-7.2.x false

	generate_docker_hub_bundle_image_page commerce-enterprise "Commerce Enterprise" 2.1.2-7.2.x true

	generate_docker_hub_bundle_image_page portal Portal 7.3.5-ga6 false
}

main ${@}