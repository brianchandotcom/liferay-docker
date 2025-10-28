#!/bin/bash

source ../_liferay_common.sh
source ../_release_common.sh
source ../_test_common.sh
source ./_package.sh

function main {
	set_up

	if [ "${#}" -eq 1 ]
	then
		"${1}"
	else
		test_package_generate_javadocs
		test_package_generate_release_properties_file
		test_package_not_generate_javadocs
		test_package_not_generate_release_properties_file
		test_package_portal_dependencies
	fi

	tear_down
}

function set_up {
	export LIFERAY_RELEASE_PRODUCT_NAME="dxp"
	export _BUILD_DIR="${PWD}/test-dependencies"
	export _BUILD_TIMESTAMP="1234567890"
	export _PROJECTS_DIR="${PWD}/test-dependencies/expected"

	common_set_up

	mkdir --parents "${_BUILD_DIR}/release"

	lc_cd test-dependencies

	lc_download \
		https://releases.liferay.com/dxp/7.3.10-u36/liferay-dxp-tomcat-7.3.10-u36-1706652128.zip \
		liferay-dxp-tomcat-7.3.10-u36-1706652128.zip 1> /dev/null

	unzip -oq liferay-dxp-tomcat-7.3.10-u36-1706652128.zip -d "${_BUILD_DIR}/release"

	lc_cd ..
}

function tear_down {
	common_tear_down

	rm --force "${_BUILD_DIR}/liferay-dxp-tomcat-7.3.10-u36-1706652128.zip"
	rm --force --recursive "${_BUILD_DIR}/release"

	unset LIFERAY_RELEASE_PRODUCT_NAME
	unset _BUILD_DIR
	unset _BUILD_TIMESTAMP
	unset _PRODUCT_VERSION
	unset _PROJECTS_DIR
}

function test_package_generate_javadocs {
	_test_package_generate_javadocs "2025.q3.0"
	_test_package_generate_javadocs "2026.q1.0-lts"
	_test_package_generate_javadocs "7.3.10-ga1"
	_test_package_generate_javadocs "7.3.10-u36"
	_test_package_generate_javadocs "7.4.3.132-ga132"
}

function test_package_generate_release_properties_file {
	_BUNDLES_DIR="${_BUILD_DIR}"

	_test_package_generate_release_properties_file "2025.q1.18-lts" "9.0.107" "2025-10-10"
	_test_package_generate_release_properties_file "2025.q2.0" "9.0.104" "2025-05-22"

	LIFERAY_RELEASE_PRODUCT_NAME="portal"

	_test_package_generate_release_properties_file "7.4.3.132-ga132" "9.0.98" "2025-02-18"

	LIFERAY_RELEASE_PRODUCT_NAME="dxp"
}

function test_package_not_generate_javadocs {
	_test_package_not_generate_javadocs "2025.q2.0"
	_test_package_not_generate_javadocs "2025.q3.1"
	_test_package_not_generate_javadocs "2026.q1.1-lts"
	_test_package_not_generate_javadocs "7.4.13-u136"
}

function test_package_not_generate_release_properties_file {
	_BUNDLES_DIR=""

	generate_release_properties_file &> /dev/null

	assert_equals "${?}" "${LIFERAY_COMMON_EXIT_CODE_BAD}"
}

function test_package_portal_dependencies {
	_PRODUCT_VERSION="7.3.10-u36"

	lc_cd "${_BUILD_DIR}/release"

	package_portal_dependencies

	unzip -oq "liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-client-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip"
	unzip -oq "liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-dependencies-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip"

	assert_equals \
		"$(ls -1 liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-client-${_PRODUCT_VERSION})" \
		"$(cat ${_BUILD_DIR}/expected/test_publishing_liferay-dxp-client-7.3.10-u36.txt)" \
		"$(ls -1 liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-dependencies-${_PRODUCT_VERSION})" \
		"$(cat ${_BUILD_DIR}/expected/test_publishing_liferay-dxp-dependencies-7.3.10-u36.txt)"

	rm --force "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-client-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip"
	rm --force "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-dependencies-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip"
}

function _test_package_generate_javadocs {
	_PRODUCT_VERSION="${1}"

	generate_javadocs &> /dev/null

	assert_equals "${?}" "${LIFERAY_COMMON_EXIT_CODE_OK}"
 }

function _test_package_generate_release_properties_file {
	_BUILDER_SHA="test1234"
	_GIT_SHA="test1234"
	_PRODUCT_VERSION="${1}"

	echo "test1234" > "liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-tomcat-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.7z.sha512"

	mkdir --parents "${_BUNDLES_DIR}/tomcat"

	echo "Apache Tomcat Version ${2}" > "${_BUNDLES_DIR}/tomcat/RELEASE-NOTES"

	generate_release_properties_file &> /dev/null

	sed \
		--expression "s/release.date=.*/release.date=${3}/" \
		--in-place \
		release.properties

	assert_equals \
		release.properties \
		test-dependencies/expected/release_$(echo "${_PRODUCT_VERSION}").properties

	rm --force --recursive "${_BUNDLES_DIR}/tomcat"
	rm --force "liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-tomcat-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.7z.sha512"
	rm --force release.properties
}

function _test_package_not_generate_javadocs {
	_PRODUCT_VERSION="${1}"

	generate_javadocs &> /dev/null

	assert_equals "${?}" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
}

main "${@}"