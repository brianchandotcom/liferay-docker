#!/bin/bash

source ./_common.sh

function check_usage {
	if [ ! -n "${1}" ] ||
	   [[ ("${1}" != "commit") &&
	   ("${1}" != "display") &&
	   ("${1}" != "fail-on-change") &&
	   ("${1}" != "get-version") ]]
	then
		echo "Usage: ${0} <command>"
		echo ""
		echo "This script requires the first parameter to be set to one of these options:"
		echo ""
		echo "    commit: Write and commit the necessary version change with the change log"
		echo "    display: Display the required version number change"
		echo "    fail-on-change: The script will return an error code if there was a version number changing commit since the last release notes change"
		echo "    get-version: Return the current version number"

		exit 1
	fi

	check_utils git sed sort tr
}

function check_version_bump {
	local has_version_bump=$(\
		git log --pretty=oneline "${RELEASE_NOTES_LATEST_SHA}..${RELEASE_NOTES_CURRENT_SHA}" | \
			grep "${1}" | \
			grep --invert-match "Revert.*${1}" | \
			while read -r commit_message
			do
				local commit=$(echo ${commit_message} | cut -d ' ' -f 1)

				if (!(git log "${RELEASE_NOTES_LATEST_SHA}..${RELEASE_NOTES_CURRENT_SHA}" | grep "This reverts commit ${commit}" > /dev/null))
				then
					echo "true"
				fi
			done | \
			cat | \
			uniq)

	if [ "${has_version_bump}" = "true" ]
	then
		return 0
	fi

	return 1
}

function generate_release_notes {
	if [ ! -n "${RELEASE_NOTES_CHANGE_LOG}" ]
	then
		return
	fi

	echo "Bump version from ${RELEASE_NOTES_LATEST_VERSION} to ${RELEASE_NOTES_NEW_VERSION}."

	if [ "${1}" == "commit" ]
	then
		(
			echo ""
			echo "#"
			echo "# Liferay Docker Image Version ${RELEASE_NOTES_NEW_VERSION}"
			echo "#"
			echo ""
			echo "docker.image.change.log-${RELEASE_NOTES_NEW_VERSION}=${RELEASE_NOTES_CHANGE_LOG}"
			echo "docker.image.git.id-${RELEASE_NOTES_NEW_VERSION}=${RELEASE_NOTES_CURRENT_SHA}"
		) >> .releng/docker-image.changelog

		git add .releng/docker-image.changelog

		git commit -m "${RELEASE_NOTES_NEW_VERSION} change log"
	fi
}

function get_change_log {
	RELEASE_NOTES_CURRENT_SHA=$(git log -1 --pretty=%H)

	RELEASE_NOTES_CHANGE_LOG=$(\
		git log --grep "^DOCKER-" --pretty=oneline "${RELEASE_NOTES_LATEST_SHA}..${RELEASE_NOTES_CURRENT_SHA}" | \
			grep --invert-match "Revert.*" | \
			while read -r commit_message
			do
				local commit=$(echo ${commit_message} | cut -d ' ' -f 1)

				if (!(git log "${RELEASE_NOTES_LATEST_SHA}..${RELEASE_NOTES_CURRENT_SHA}" | grep "This reverts commit ${commit}" > /dev/null))
				then
					echo ${commit_message} | cut -d ' ' -f 2
					echo -n " "
				fi
			done | \
			cat | \
			uniq | \
			tr -d "\n")

	if [ "${1}" == "fail-on-change" ] && [ -n "${RELEASE_NOTES_CHANGE_LOG}" ]
	then
		echo "There was a change in the repository which requires regenerating the release notes."
		echo ""
		echo "Run \"./release_notes.sh commit\" to commit the updated change log."

		exit 1
	fi
}

function get_latest_version {
	local git_line=$(grep 'docker.image.git.id' .releng/docker-image.changelog | tail -n1)

	RELEASE_NOTES_LATEST_SHA=${git_line#*=}

	RELEASE_NOTES_LATEST_VERSION=${git_line#*-}
	RELEASE_NOTES_LATEST_VERSION=${RELEASE_NOTES_LATEST_VERSION%=*}

	RELEASE_NOTES_VERSION_MAJOR=${RELEASE_NOTES_LATEST_VERSION%%.*}

	RELEASE_NOTES_VERSION_MINOR=${RELEASE_NOTES_LATEST_VERSION#*.}
	RELEASE_NOTES_VERSION_MINOR=${RELEASE_NOTES_VERSION_MINOR%.*}

	RELEASE_NOTES_VERSION_MICRO=${RELEASE_NOTES_LATEST_VERSION##*.}
}

function get_new_version {
	if [ ! -n "${RELEASE_NOTES_CHANGE_LOG}" ]
	then
		return
	fi

	if (check_version_bump "#majorchange")
	then
		RELEASE_NOTES_VERSION_MAJOR=$((RELEASE_NOTES_VERSION_MAJOR+1))
		RELEASE_NOTES_VERSION_MINOR=0
		RELEASE_NOTES_VERSION_MICRO=0
	elif (check_version_bump "#minorchange")
	then
		RELEASE_NOTES_VERSION_MINOR=$((RELEASE_NOTES_VERSION_MINOR+1))
		RELEASE_NOTES_VERSION_MICRO=0
	else
		RELEASE_NOTES_VERSION_MICRO=$((RELEASE_NOTES_VERSION_MICRO+1))
	fi

	RELEASE_NOTES_NEW_VERSION="${RELEASE_NOTES_VERSION_MAJOR}.${RELEASE_NOTES_VERSION_MINOR}.${RELEASE_NOTES_VERSION_MICRO}"
}

function main {
	check_usage "${@}"

	get_latest_version "${@}"

	get_change_log "${@}"

	get_new_version "${@}"

	print_version "${@}"

	generate_release_notes "${@}"
}

function print_version {
	if [ "${1}" == "get-version" ]
	then
		if [ -n "${RELEASE_NOTES_CHANGE_LOG}" ]
		then
			echo "${RELEASE_NOTES_NEW_VERSION}-snapshot"
		else
			echo "${RELEASE_NOTES_LATEST_VERSION}"
		fi

		exit
	fi
}

main "${@}"