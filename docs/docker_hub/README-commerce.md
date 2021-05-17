## Tags

For [tags](https://hub.docker.com/r/liferay/commerce/tags) that follow the format *{version}-d{docker-version}-{date}*, *version* denotes the version of Liferay Commerce, *docker-version* denotes the version of the [parent (`liferay/base`) image](https://hub.docker.com/r/liferay/base), and *date* denotes the date when the Docker image was made.

[Tags](https://hub.docker.com/r/liferay/commerce/tags) that follow the format *{version}* always point to the latest tag that follows the format *{version}-d{docker-version}-{date}*.

New Docker images will be made even for older releases of Liferay Commerce as our support for Docker evolves.


## Running

To start Liferay Commerce, replace {tag} and execute:

`docker run -it -p 8080:8080 liferay/commerce:{tag}`

For example:

`docker run -it -p 8080:8080 liferay/commerce:2.0.7-7.2.x`

The `-it` argument allows you to stop the container with CTRL-C. Otherwise, you have to use `docker kill {containerId}` to stop the container.

The `-p 8080:8080` argument maps the container's port 8080 with the host's port 8080 so that you can access Liferay Commerce from a browser.

## Environment Variables

You can tune the default JVM parameters by setting the environment variable `LIFERAY_JVM_OPTS`.

You can customize the behavior of Liferay Commerce via environment variables that map to portal.properties. For example, if you want to provide only English and Portuguese, you could create a portal-ext.properties with the entry:

`locales.enabled=en_US,pt_BR`

Or, you could set the environment variable:

`LIFERAY_LOCALES_PERIOD_ENABLED=en_US,pt_BR`

Each property's respective environment variable is documented in [portal.properties](https://github.com/liferay/liferay-portal/blob/master/portal-impl/src/portal.properties). Search for the text `Env:`.

Environment variables take precedence over portal.properties.

## File System

Docker containers are transient. Whenever you reboot a container, all changes on its file system are lost.

To quickly test changes without building a new image, map the host's file system to the container's file system.

Start the container with the option `-v $(pwd)/xyz123:/mnt/liferay` to bridge `$(pwd)/xyz123` in the host operating system to `/mnt/liferay` on the container.

Files in the host directory `$(pwd)/xyz123/files` are also available in the container directory `/mnt/liferay/files` and will be copied to `/opt/liferay` before Liferay Commerce starts.

For example, if you want to modify Tomcat's setenv.sh file, then place your changes in `$(pwd)/xyz123/files/tomcat/bin/setenv.sh` and setenv.sh will be overwritten in `/opt/liferay/tomcat/bin/setenv.sh` before Liferay Commerce starts.

## Scripts

All scripts in the container directory `/mnt/liferay/scripts` will be executed before before Liferay Commerce starts. Place your scripts in `$(pwd)/xyz123/scripts`.

## Deploy

Copy files to `$(pwd)/xyz123/deploy` on the host operating system to deploy modules to Liferay Commerce at runtime.

## About

Images are built based off of OpenJDK on Alpine. More information can be found in the Dockerfile at http://github.com/liferay/liferay-docker.

## License

This library, *Liferay Commerce Community Edition*, is free software ("Licensed Software"); you can redistribute it and/or modify it under the terms of the [GNU Lesser General Public License](http://www.gnu.org/licenses/lgpl-2.1.html) as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; including but not limited to, the implied warranty of MERCHANTABILITY, NONINFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. See the [GNU Lesser General Public License](http://www.gnu.org/licenses/lgpl-2.1.html) for more details.

You should have received a copy of the [GNU Lesser General Public License](http://www.gnu.org/licenses/lgpl-2.1.html) along with this library; if not, write to

Free Software Foundation, Inc.
51 Franklin Street, Fifth Floor
Boston, MA 02110-1301 USA
