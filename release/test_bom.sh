#!/bin/bash

source ../_test_common.sh
source _bom.sh
source _liferay_common.sh

function main {
	set_up

	if [ $? -eq "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	test_generate_pom_release_bom_compile_only_dxp
	test_generate_pom_release_bom_third_party_dxp

	LIFERAY_RELEASE_PRODUCT_NAME="portal"
	_PRODUCT_VERSION="7.4.3.120-ga120"

	test_generate_pom_release_bom_compile_only_portal
	test_generate_pom_release_bom_third_party_portal

	tear_down
}

function set_up {
	export LIFERAY_RELEASE_PRODUCT_NAME="dxp"
	export _BUILD_TIMESTAMP=12345
	export _PRODUCT_VERSION="2024.q2.6"
	export _RELEASE_ROOT_DIR="${PWD}"

	export _PROJECTS_DIR="${_RELEASE_ROOT_DIR}"/../..
	export _RELEASE_TOOL_DIR="${_RELEASE_ROOT_DIR}"

	if [ ! -d "${_PROJECTS_DIR}/liferay-portal-ee" ]
	then
		echo "The directory ${_PROJECTS_DIR}/liferay-portal-ee does not exist."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi
	
	cd "${_PROJECTS_DIR}"/liferay-portal-ee

	git branch --delete "${_PRODUCT_VERSION}" &> /dev/null

	git fetch --no-tags upstream "${_PRODUCT_VERSION}":"${_PRODUCT_VERSION}" &> /dev/null

	git checkout --quiet "${_PRODUCT_VERSION}"

	cd "${_RELEASE_ROOT_DIR}"
}

function tear_down {
	unset LIFERAY_RELEASE_PRODUCT_NAME
	unset _BUILD_TIMESTAMP
	unset _PRODUCT_VERSION
	unset _PROJECTS_DIR
	unset _RELEASE_ROOT_DIR
	unset _RELEASE_TOOL_DIR
}

function test_generate_pom_release_bom_compile_only_dxp {
	generate_pom_release_bom_compile_only

	assert_equals \
		release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom \
		test-dependencies/expected.dxp.release.bom.compile.only.pom

	rm release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom
}

function test_generate_pom_release_bom_compile_only_portal {
	generate_pom_release_bom_compile_only

	assert_equals \
		release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom \
		test-dependencies/expected.portal.release.bom.compile.only.pom

	rm release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom
}

function test_generate_pom_release_bom_third_party_dxp {
	generate_pom_release_bom_compile_only

	generate_pom_release_bom_third_party

	assert_equals \
		release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.third.party-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom \
		test-dependencies/expected.dxp.release.bom.third.party.pom

	rm release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom
	rm release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.third.party-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom
}

function test_generate_pom_release_bom_third_party_portal {
	generate_pom_release_bom_compile_only

	generate_pom_release_bom_third_party

	assert_equals \
		release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.third.party-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom \
		test-dependencies/expected.portal.release.bom.third.party.pom

	rm release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom
	rm release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.third.party-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom
}

main