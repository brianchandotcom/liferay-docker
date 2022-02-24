#!/bin/bash

source ./_common.sh

function build_docker_image {
	local beautysh_image_version=0.1.0

	DOCKER_IMAGE_TAGS=()
	DOCKER_IMAGE_TAGS+=("${LIFERAY_DOCKER_REPOSITORY}liferay/beautysh:${beautysh_image_version}-${TIMESTAMP}")
	DOCKER_IMAGE_TAGS+=("${LIFERAY_DOCKER_REPOSITORY}liferay/beautysh:${beautysh_image_version%.*}")

	docker build \
		--build-arg LABEL_BUILD_DATE=$(date "${CURRENT_DATE}" "+%Y-%m-%dT%H:%M:%SZ") \
		--build-arg LABEL_NAME="Liferay Beautysh" \
		--build-arg LABEL_VCS_REF=$(git rev-parse HEAD) \
		--build-arg LABEL_VCS_URL="https://github.com/liferay/beautysh" \
		--build-arg LABEL_VERSION="${beautysh_image_version}" \
		$(get_docker_image_tags_args "${DOCKER_IMAGE_TAGS[@]}") \
		"${TEMP_DIR}" || exit 1
}

function main {
	make_temp_directory templates/beautysh

	build_docker_image

	log_in_to_docker_hub

	push_docker_images "${1}"
}

main "${@}"