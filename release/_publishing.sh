#!/bin/bash

function add_fixed_issues_to_patcher_project_version {
	lc_download "https://releases.liferay.com/dxp/${_PRODUCT_VERSION}/release-notes.txt" release-notes.txt

	if [ "${?}" -ne 0 ]
	then
		lc_log ERROR "Unable to download release-notes.txt."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	IFS=',' read -r -a fixed_issues_array < "release-notes.txt"

	local fixed_issues_array_length="${#fixed_issues_array[@]}"

	local fixed_issues_array_part_length=$((fixed_issues_array_length / 4))

	for counter in {0..3}
	do
		local start_index=$((counter * fixed_issues_array_part_length))

		if [ "${counter}" -eq 3 ]
		then
			fixed_issues_array_part_length=$((fixed_issues_array_length - start_index))
		fi

		IFS=',' fixed_issues="${fixed_issues_array[*]:start_index:fixed_issues_array_part_length}"

		local update_fixed_issues_response=$(curl \
			"https://patcher.liferay.com/api/jsonws/osb-patcher-portlet.project_versions/updateFixedIssues" \
			--data-raw "fixedIssues=${fixed_issues}&patcherProjectVersionId=${1}" \
			--max-time 10 \
			--retry 3 \
			--user "${LIFERAY_RELEASE_PATCHER_PORTAL_EMAIL_ADDRESS}:${LIFERAY_RELEASE_PATCHER_PORTAL_PASSWORD}")

		if [ $(echo "${update_fixed_issues_response}" | jq -r '.status') -eq 200 ]
		then
			lc_log INFO "Adding fixed issues to Liferay Patcher project version ${2}."
		else
			lc_log ERROR "Unable to add fixed issues to Liferay Patcher project ${2}:"

			lc_log ERROR "${update_fixed_issues_response}"

			rm -f release-notes.txt

			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi
	done

	lc_log INFO "Added fixed issues to Liferay Patcher project ${2}."

	rm -f release-notes.txt
}

function add_patcher_project_version {
	if [[ "${_PRODUCT_VERSION}" == *ga* ]]
	then
		lc_log INFO "Skipping the add patcher project version step for ${_PRODUCT_VERSION}."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local patcher_project_version="$(get_patcher_project_version)"

	local add_by_name_response=$(\
		curl \
			"https://patcher.liferay.com/api/jsonws/osb-patcher-portlet.project_versions/addByName" \
			--data-raw "combinedBranch=true&committish=${patcher_project_version}&fixedIssues=&name=${patcher_project_version}&productVersionLabel=$(get_patcher_product_version_label)&repositoryName=liferay-portal-ee&rootPatcherProjectVersionName=$(get_root_patcher_project_version_name)" \
			--max-time 10 \
			--retry 3 \
			--user "${LIFERAY_RELEASE_PATCHER_PORTAL_EMAIL_ADDRESS}:${LIFERAY_RELEASE_PATCHER_PORTAL_PASSWORD}")

	if [ $(echo "${add_by_name_response}" | jq -r '.status') -eq 200 ]
	then
		lc_log INFO "Added Liferay Patcher project version ${patcher_project_version}."

		add_fixed_issues_to_patcher_project_version $(echo "${add_by_name_response}" | jq -r '.data.patcherProjectVersionId') "${patcher_project_version}"
	else
		lc_log ERROR "Unable to add Liferay Patcher project ${patcher_project_version}:"

		lc_log ERROR "${add_by_name_response}"

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function check_url {
	local file_url="${1}"

	if (curl \
			"${file_url}" \
			--fail \
			--head \
			--max-time 300 \
			--output /dev/null \
			--retry 3 \
			--retry-delay 10 \
			--silent \
			--user "${LIFERAY_RELEASE_NEXUS_REPOSITORY_USER}:${LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD}")
	then
		lc_log DEBUG "File is available at ${file_url}."

		return "${LIFERAY_COMMON_EXIT_CODE_OK}"
	else
		lc_log DEBUG "Unable to access ${file_url}."

		return "${LIFERAY_COMMON_EXIT_CODE_MISSING_RESOURCE}"
	fi
}

function get_patcher_product_version_label {
	if [[ "${_PRODUCT_VERSION}" == 7.3.* ]]
	then
		echo "DXP 7.3"
	elif [[ "${_PRODUCT_VERSION}" == 7.4.* ]]
	then
		echo "DXP 7.4"
	else
		echo "Quarterly Releases"
	fi
}

function get_patcher_project_version {
	if [[ "${_PRODUCT_VERSION}" == 7.3.* ]]
	then
		echo "fix-pack-dxp-$(echo "${_PRODUCT_VERSION}" | cut -d 'u' -f 2)-7310"
	else
		echo "${_ARTIFACT_VERSION}"
	fi
}

function get_root_patcher_project_version_name {
	if [[ "${_PRODUCT_VERSION}" == 7.3.* ]]
	then
		echo "fix-pack-base-7310"
	elif [[ "${_PRODUCT_VERSION}" == 7.4.* ]]
	then
		echo "7.4.13-ga1"
	else
		echo ""
	fi
}

function has_ssh_connection {
	ssh "root@${1}" "exit" &> /dev/null

	if [ $? -eq 0 ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_OK}"
	fi

	return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
}

function init_gcs {
	if [ ! -n "${LIFERAY_RELEASE_GCS_TOKEN}" ]
	then
		lc_log INFO "Set the environment variable LIFERAY_RELEASE_GCS_TOKEN."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	gcloud auth activate-service-account --key-file "${LIFERAY_RELEASE_GCS_TOKEN}"
}

function upload_bom_file {
	local nexus_repository_name="${1}"

	local nexus_repository_url="https://repository.liferay.com/nexus/service/local/repositories"

	local file_path="${2}"

	local file_name="${file_path##*/}"

	local component_name="${file_name/%-*}"


	if [ "${nexus_repository_name}" == "liferay-public-releases" ]
	then
		local file_url="${nexus_repository_url}/${nexus_repository_name}/content/com/liferay/portal/${component_name}/${_ARTIFACT_VERSION}/${file_name}"
	else
		local file_url="${nexus_repository_url}/${nexus_repository_name}/content/com/liferay/portal/${component_name}/${_ARTIFACT_RC_VERSION}/${file_name}"
	fi

	_upload_to_nexus "${file_path}" "${file_url}" || return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	_upload_to_nexus "${file_path}.MD5" "${file_url}.md5" || return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	_upload_to_nexus "${file_path}.sha512" "${file_url}.sha512" || return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
}

function upload_boms {
	local nexus_repository_name="${1}"

	if [ "${LIFERAY_RELEASE_UPLOAD}" != "true" ] && [ "${nexus_repository_name}" == "xanadu" ]
	then
		lc_log INFO "Set the environment variable LIFERAY_RELEASE_UPLOAD to \"true\" to enable."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	if [ -z "${LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD}" ] || [ -z "${LIFERAY_RELEASE_NEXUS_REPOSITORY_USER}" ]
	then
		 lc_log ERROR "Either \${LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD} or \${LIFERAY_RELEASE_NEXUS_REPOSITORY_USER} is undefined."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	if [ "${nexus_repository_name}" == "liferay-public-releases" ]
	then
		local upload_dir="${_PROMOTION_DIR}"
	else
		local upload_dir="${_BUILD_DIR}/release"
	fi

	find "${upload_dir}" -regextype egrep -regex '.*/*.(jar|pom)' -print0 | while IFS= read -r -d '' file_path
	do
		upload_bom_file "${nexus_repository_name}" "${file_path}" || return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	done
}

function upload_opensearch_2 {
	gsutil mv -r "${_BUNDLES_DIR}/osgi/portal/com.liferay.portal.search.opensearch2.api.jar" "gs://liferay-releases/opensearch2/${LIFERAY_RELEASE_PRODUCT_NAME}/${_PRODUCT_VERSION}/com.liferay.portal.search.opensearch2.api.jar"
	gsutil mv -r "${_BUNDLES_DIR}/osgi/portal/com.liferay.portal.search.opensearch2.impl.jar" "gs://liferay-releases/opensearch2/${LIFERAY_RELEASE_PRODUCT_NAME}/${_PRODUCT_VERSION}/com.liferay.portal.search.opensearch2.impl.jar"
}

function upload_hotfix {
	if [ "${LIFERAY_RELEASE_UPLOAD}" != "true" ]
	then
		lc_log INFO "Set the environment variable LIFERAY_RELEASE_UPLOAD to \"true\" to enable."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	if (has_ssh_connection "lrdcom-vm-1")
	then
		lc_log INFO "Connecting to lrdcom-vm-1."

		ssh root@lrdcom-vm-1 mkdir -p "/www/releases.liferay.com/dxp/hotfix/${_PRODUCT_VERSION}/"

		#
		# shellcheck disable=SC2029
		#

		if (ssh root@lrdcom-vm-1 ls "/www/releases.liferay.com/dxp/hotfix/${_PRODUCT_VERSION}/" | grep -q "${_HOTFIX_FILE_NAME}")
		then
			lc_log INFO "Skipping the upload of ${_HOTFIX_FILE_NAME} because it already exists."

			echo "# Uploaded" > ../output.md
			echo " - https://releases.liferay.com/dxp/hotfix/${_PRODUCT_VERSION}/${_HOTFIX_FILE_NAME}" >> ../output.md

			return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
		fi

		scp "${_BUILD_DIR}/${_HOTFIX_FILE_NAME}" root@lrdcom-vm-1:"/www/releases.liferay.com/dxp/hotfix/${_PRODUCT_VERSION}/"
	else
		lc_log INFO "Skipping lrdcom-vm-1."
	fi

	if (gsutil ls "gs://liferay-releases-hotfix/${_PRODUCT_VERSION}" | grep "${_HOTFIX_FILE_NAME}")
	then
		lc_log ERROR "Skipping the upload of ${_HOTFIX_FILE_NAME} to GCP because it already exists."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	gsutil cp "${_BUILD_DIR}/${_HOTFIX_FILE_NAME}" "gs://liferay-releases-hotfix/${_PRODUCT_VERSION}"

	echo "# Uploaded" > ../output.md
	echo " - https://releases.liferay.com/dxp/hotfix/${_PRODUCT_VERSION}/${_HOTFIX_FILE_NAME}" >> ../output.md
}

function upload_release {
	if [ "${LIFERAY_RELEASE_UPLOAD}" != "true" ]
	then
		lc_log INFO "Set the environment variable LIFERAY_RELEASE_UPLOAD to \"true\" to enable."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_cd "${_BUILD_DIR}"/release

	echo "# Uploaded" > ../output.md

	local ssh_connection="false"

	if (has_ssh_connection "lrdcom-vm-1")
	then
		lc_log INFO "Connecting to lrdcom-vm-1."

		ssh_connection="true"

		ssh root@lrdcom-vm-1 rm -r "/www/releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/release-candidates/${_PRODUCT_VERSION}-*"

		ssh root@lrdcom-vm-1 mkdir -p "/www/releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/release-candidates/${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}"
	else
		lc_log INFO "Skipping lrdcom-vm-1."
	fi

	gsutil rm -r "gs://liferay-releases-candidates/${_PRODUCT_VERSION}-*"

	for file in $(ls --almost-all --ignore "*.jar*" --ignore "*.pom*")
	do
		if [ -f "${file}" ]
		then
			echo "Copying ${file}."

			gsutil cp "${_BUILD_DIR}/release/${file}" "gs://liferay-releases-candidates/${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}/"

			if [ "${ssh_connection}" == "true" ]
			then
				scp "${file}" root@lrdcom-vm-1:"/www/releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/release-candidates/${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}"
			fi
		fi
	done
}

function upload_to_docker_hub {
	_update_bundles_yml

	lc_cd "${_BASE_DIR}"

	LIFERAY_DOCKER_IMAGE_FILTER="${_PRODUCT_VERSION}" ./build_all_images.sh --push
}

function _update_bundles_yml {
	local product_version_key="$(echo "${_PRODUCT_VERSION}" | cut -d '-' -f 1)"

	if (yq eval ".\"${product_version_key}\" | has(\"${_PRODUCT_VERSION}\")" "${_BASE_DIR}/bundles.yml" | grep -q "true") ||
	   (yq eval ".quarterly | has(\"${_PRODUCT_VERSION}\")" "${_BASE_DIR}/bundles.yml" | grep -q "true")
	then
		lc_log INFO "The ${_PRODUCT_VERSION} product version was already published."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	if [[ "${_PRODUCT_VERSION}" == *q* ]]
	then
		local latest_key=$(yq eval ".quarterly | keys | .[-1]" "${_BASE_DIR}/bundles.yml")

		yq --indent 4 --inplace eval "del(.quarterly.\"${latest_key}\".latest)" "${_BASE_DIR}/bundles.yml"
		yq --indent 4 --inplace eval ".quarterly.\"${_PRODUCT_VERSION}\".latest = true" "${_BASE_DIR}/bundles.yml"
	fi

	if [[ "${_PRODUCT_VERSION}" == 7.3.* ]]
	then
		yq --indent 4 --inplace eval ".\"${product_version_key}\".\"${_PRODUCT_VERSION}\" = {}" "${_BASE_DIR}/bundles.yml"
	fi

	if [[ "${_PRODUCT_VERSION}" == 7.4.*-u* ]]
	then
		local nightly_bundle_url=$(yq eval ".\"${product_version_key}\".\"${product_version_key}.nightly\".bundle_url" "${_BASE_DIR}/bundles.yml")

		yq --indent 4 --inplace eval "del(.\"${product_version_key}\".\"${product_version_key}.nightly\")" "${_BASE_DIR}/bundles.yml"
		yq --indent 4 --inplace eval ".\"${product_version_key}\".\"${_PRODUCT_VERSION}\" = {}" "${_BASE_DIR}/bundles.yml"
		yq --indent 4 --inplace eval ".\"${product_version_key}\".\"${product_version_key}.nightly\".bundle_url = \"${nightly_bundle_url}\"" "${_BASE_DIR}/bundles.yml"
	fi

	if [[ "${_PRODUCT_VERSION}" == 7.4.*-ga* ]]
	then
		local ga_bundle_url="releases-cdn.liferay.com/portal/${_PRODUCT_VERSION}/"$(curl -fsSL "https://releases-cdn.liferay.com/portal/${_PRODUCT_VERSION}/.lfrrelease-tomcat-bundle")

		perl -i -0777pe 's/\s+latest: true(?!7.4.13:)//' "${_BASE_DIR}/bundles.yml"

		sed -i "/7.4.13:/i ${product_version_key}:" "${_BASE_DIR}/bundles.yml"

		yq --indent 4 --inplace eval ".\"${product_version_key}\".\"${_PRODUCT_VERSION}\".bundle_url = \"${ga_bundle_url}\"" "${_BASE_DIR}/bundles.yml"
		yq --indent 4 --inplace eval ".\"${product_version_key}\".\"${_PRODUCT_VERSION}\".latest = true" "${_BASE_DIR}/bundles.yml"
	fi

	sed -i "s/[[:space:]]{}//g" "${_BASE_DIR}/bundles.yml"

	truncate -s -1 "${_BASE_DIR}/bundles.yml"

	if [[ ! " ${@} " =~ " --test " ]]
	then
		git add "${_BASE_DIR}/bundles.yml"

		git commit -m "Add ${_PRODUCT_VERSION} to bundles.yml."

		git push upstream master
	fi
}

function _upload_to_nexus {
	local file_path="${1}"
	local file_url="${2}"

	lc_log INFO "Uploading ${file_path} to ${file_url}."

	if (check_url "${file_url}")
	then
		lc_log "Skipping the upload of ${file_path} to ${file_url} because it already exists."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	else
		lc_log INFO "Uploading ${file_path} to ${file_url}."

		curl \
			--fail \
			--max-time 300 \
			--retry 3 \
			--retry-delay 10 \
			--silent \
			--upload-file "${file_path}" \
			--user "${LIFERAY_RELEASE_NEXUS_REPOSITORY_USER}:${LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD}" \
			"${file_url}"
	fi
}