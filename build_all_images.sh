#!/bin/bash

source ./_common.sh

BUILD_ALL_IMAGES_PUSH=${1}

function build_base_image {
	local base_image_version=$(docker image inspect --format '{{index .Config.Labels "org.label-schema.version"}}' liferay/base:latest)

	if [[ "${LIFERAY_DOCKER_DEVELOPER_MODE}" != "true" ]] && [[ ${base_image_version} == $(./release_notes.sh get-version) ]]
	then
		return
	fi

	log_in_to_docker_hub

	docker pull liferay/base:latest

	base_image_version=$(docker image inspect --format '{{index .Config.Labels "org.label-schema.version"}}' liferay/base:latest)

	if [[ "${LIFERAY_DOCKER_DEVELOPER_MODE}" != "true" ]] && [[ ${base_image_version} == $(./release_notes.sh get-version) ]]
	then
		echo "Latest image version matches with local release version."

		return
	fi

	echo ""
	echo "Building Docker image base."
	echo ""

	time ./build_base_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee -a "${LOGS_DIR}"/base.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: base" >> "${LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: base" >> "${LOGS_DIR}/results"
	fi
}

function build_bundle_image {
	local query=${1}
	local version=${2}

	local bundle_url=$(get_string $(yq "${query}".bundle_url < bundles.yml))
	local fix_pack_url=$(get_string $(yq "${query}".fix_pack_url < bundles.yml))
	local test_hotfix_url=$(get_string $(yq "${query}".test_hotfix_url < bundles.yml))
	local test_installed_patch=$(get_string $( yq "${query}".test_installed_patch < bundles.yml))

	if [ ! -n "${version}" ]
	then
		local build_id=${bundle_url##*/}
	else
		local build_id=${version}
	fi

	echo ""
	echo "Building Docker image ${build_id} based on ${bundle_url}."
	echo ""

	LIFERAY_DOCKER_FIX_PACK_URL=${fix_pack_url} LIFERAY_DOCKER_RELEASE_FILE_URL=${bundle_url} LIFERAY_DOCKER_RELEASE_VERSION=${version} LIFERAY_DOCKER_TEST_HOTFIX_URL=${test_hotfix_url} LIFERAY_DOCKER_TEST_INSTALLED_PATCHES=${test_installed_patch} time ./build_bundle_image.sh "${BUILD_ALL_IMAGES_PUSH}" 2>&1 | tee "${LOGS_DIR}/${build_id}.log"

	local build_bundle_image_exit_code=${PIPESTATUS[0]}

	if [ "${build_bundle_image_exit_code}" -gt 0 ]
	then
		echo "FAILED: ${build_id}" >> "${LOGS_DIR}/results"

		if [ "${build_bundle_image_exit_code}" -eq 4 ]
		then
			echo "Detected a license failure while building image ${build_id}." > "${LOGS_DIR}/license-failure"

			echo "There is an existing license failure."

			exit 4
		fi
	else
		echo "SUCCESS: ${build_id}" >> "${LOGS_DIR}/results"
	fi
}

function build_bundle_images {

	#
	# LIFERAY_DOCKER_IMAGE_FILTER="7.2.10-dxp-1 "  ./build_all_images.sh
	# LIFERAY_DOCKER_IMAGE_FILTER=7.2.10 ./build_all_images.sh
	#

	local main_keys=$(yq '' < bundles.yml | grep -v '  .*' | sed 's/://')

	local specified_version=${LIFERAY_DOCKER_IMAGE_FILTER}

	if [ -z "${LIFERAY_DOCKER_IMAGE_FILTER}" ]
	then
		specified_version="*"
	fi

	local search_output=$(yq .\""${specified_version}"\" < bundles.yml)

	if [[ "${search_output}" != "null" ]]
	then
		local versions=$(echo "${search_output}"  | grep '^.*:$' | sed 's/://')

		for version in ${versions}
		do
			local query=.\"$(get_main_key "${main_keys}" "${version}")\".\"${version}\"

			build_bundle_image "${query}" "${version}"
		done
	else
		local main_key=$(get_main_key "${main_keys}" "${specified_version}")

		if [[ "${main_key}" = "null" ]]
		then
			echo "No bundles were found."

			exit 1
		else
			local query=.\"${main_key}\".\"${specified_version}\"

			if [[ "$(yq "${query}" < bundles.yml)" != "null" ]]
			then
				build_bundle_image "${query}" "${specified_version}"
			else
				echo "No bundles were found."

				exit 1
			fi
		fi
	fi
}

function get_main_key {
	local main_keys=${1}
	local version=${2}

	for main_key in ${main_keys}
	do
		local count=$(echo "${version}" | grep -c -E "${main_key}-|${main_key}\.")

		if [ "${count}" -gt 0 ]
		then
			echo "${main_key}"

			break
		fi
	done
}

function get_string {
	if [ "${1}" == "null" ]
	then
		echo ""
	else
		echo "${1}"
	fi
}

function main {
	if [ "${BUILD_ALL_IMAGES_PUSH}" == "push" ] && ! ./release_notes.sh fail-on-change
	then
		exit 1
	fi

	LOGS_DIR=logs-$(date "$(date)" "+%Y%m%d%H%M")

	mkdir -p "${LOGS_DIR}"

	build_base_image

	build_bundle_images

	echo ""
	echo "Results: "
	echo ""

	cat "${LOGS_DIR}/results"
}

main