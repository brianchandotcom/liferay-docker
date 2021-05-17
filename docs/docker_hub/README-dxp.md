## Tags

For [tags](https://hub.docker.com/r/liferay/dxp/tags) that follow the format *{version}-d{docker-version}-{date}*, *version* denotes the version of Liferay DXP, *docker-version* denotes the version of the [parent (`liferay/base`) image](https://hub.docker.com/r/liferay/base), and *date* denotes the date when the Docker image was made.

[Tags](https://hub.docker.com/r/liferay/dxp/tags) that follow the format *{version}* always point to the latest tag that follows the format *{version}-d{docker-version}-{date}*.

The DXP images come with a 90 day trial license. Older images will be regularly deleted and new images with a new 90 day trial license will be made available.


## Running

To start Liferay DXP, replace {tag} and execute:

`docker run -it -p 8080:8080 liferay/dxp:{tag}`

For example:

`docker run -it -p 8080:8080 liferay/dxp:7.3.10-ga1`

The `-it` argument allows you to stop the container with CTRL-C. Otherwise, you have to use `docker kill {containerId}` to stop the container.

The `-p 8080:8080` argument maps the container's port 8080 with the host's port 8080 so that you can access Liferay DXP from a browser.

## Environment Variables

You can tune the default JVM parameters by setting the environment variable `LIFERAY_JVM_OPTS`.

You can customize the behavior of Liferay DXP via environment variables that map to portal.properties. For example, if you want to provide only English and Portuguese, you could create a portal-ext.properties with the entry:

`locales.enabled=en_US,pt_BR`

Or, you could set the environment variable:

`LIFERAY_LOCALES_PERIOD_ENABLED=en_US,pt_BR`

Each property's respective environment variable is documented in [portal.properties](https://github.com/liferay/liferay-portal/blob/master/portal-impl/src/portal.properties). Search for the text `Env:`.

Environment variables take precedence over portal.properties.

## File System

Docker containers are transient. Whenever you reboot a container, all changes on its file system are lost.

To quickly test changes without building a new image, map the host's file system to the container's file system.

Start the container with the option `-v $(pwd)/xyz123:/mnt/liferay` to bridge `$(pwd)/xyz123` in the host operating system to `/mnt/liferay` on the container.

Files in the host directory `$(pwd)/xyz123/files` are also available in the container directory `/mnt/liferay/files` and will be copied to `/opt/liferay` before Liferay DXP starts.

For example, if you want to modify Tomcat's setenv.sh file, then place your changes in `$(pwd)/xyz123/files/tomcat/bin/setenv.sh` and setenv.sh will be overwritten in `/opt/liferay/tomcat/bin/setenv.sh` before Liferay DXP starts.

## Scripts

All scripts in the container directory `/mnt/liferay/scripts` will be executed before before Liferay DXP starts. Place your scripts in `$(pwd)/xyz123/scripts`.

## Deploy

Copy files to `$(pwd)/xyz123/deploy` on the host operating system to deploy modules to Liferay DXP at runtime.

## About

Images are built based off of OpenJDK on Alpine. More information can be found in the Dockerfile at http://github.com/liferay/liferay-docker.

## License

View [license information](https://web.liferay.com/c/portal/register_trial_license?eula=evaluation-license-agreement) for the software contained in this image.

As with all Docker images, these likely also contain other software which may be under other licenses (such as Bash, etc from the base distribution, along with any direct or indirect dependencies of the primary software being contained).

As for any pre-built image usage, it is the image user's responsibility to ensure that any use of this image complies with any relevant licenses for all software contained within.
