#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source _publishing.sh

function main {
	setup

	test_update_bundles_yml

	tear_down
}

function setup {
	export _RELEASE_ROOT_DIR="${PWD}"

	export _BASE_DIR="${_RELEASE_ROOT_DIR}/test-dependencies"
}

function tear_down {
	git reset HEAD~3 --hard &> /dev/null

	unset _BASE_DIR
	unset _RELEASE_ROOT_DIR
}

function test_update_bundles_yml {
	_run_update_bundles_yml "7.4.3.125-ga125"
	_run_update_bundles_yml "7.4.13-u130"
	_run_update_bundles_yml "2024.q3.1"

	assert_equals "${_BASE_DIR}/bundles.yml" "${_BASE_DIR}/expected.bundles.yml"
}

function _run_update_bundles_yml {
	_PRODUCT_VERSION="${1}"

	echo -e "Running _update_bundles_yml for ${_PRODUCT_VERSION}\n"

	_update_bundles_yml &> /dev/null
}

main