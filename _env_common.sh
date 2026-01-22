#!/bin/bash

function is_ci_slave {
	local name=${1}

	if [ -z "${name}" ]
	then
		name=$(hostname)
	fi

	if [[ "${name}" =~ ^test-[0-9]+-[0-9]+(-[0-9]+)? ]]
	then
		return 0
	fi

	return 1
}

function is_release_slave {
	local name=${1}

	if [ -z "${name}" ]
	then
		name=$(hostname)
	fi

	if [[ "${name}" =~ ^release-slave-[1-4]$ ]]
	then
		return 0
	fi

	return 1
}