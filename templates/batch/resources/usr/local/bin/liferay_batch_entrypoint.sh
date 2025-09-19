#!/bin/bash

function check_http_code {
	local http_code="$1"

	if [ "$http_code" == "000" ]
	then
		echo "Error executing curl command. Please check arguments."
		return 1
	elif [ "$http_code" -ge 400 ]
	then
		if [ "$http_code" -eq 400 ]
		then
			echo "HTTP 400 Bad Request. Please check Liferay logs for more information."
		elif [ "$http_code" -eq 401 ]
		then
			echo "HTTP 401 Unauthorized. If this was a token request, please check Liferay configuration to all /o/oauth2/token route to be public."
		elif [ "$http_code" -eq 403 ]
		then
			echo "HTTP 403 Forbidden. You do not have permission to access this resource.  If this was a resource request, please check the OAuth scopes for this application to ensure it has proper permissions."
		elif [ "$http_code" -eq 404 ]
		then
			echo "The requested resource could not be found."
		elif [ "$http_code" -eq 405 ]
		then
			echo "The method specified in the request is not allowed."
		elif [ "$http_code" -eq 500 ]
		then
			echo "There was an internal server error. Please check Liferay logs for more information."
		fi
		return 1
	fi
}

function main {
	if [ ! -n "${LIFERAY_BATCH_OAUTH_APP_ERC}" ]
	then
		echo "Set the environment variable LIFERAY_BATCH_OAUTH_APP_ERC."

		exit 1
	fi

	if [ ! -n "${LIFERAY_BATCH_CURL_OPTIONS}" ]
	then
		LIFERAY_BATCH_CURL_OPTIONS=" "
	fi

	if [ ! -n "${LIFERAY_ROUTES_CLIENT_EXTENSION}" ]
	then
		LIFERAY_ROUTES_CLIENT_EXTENSION="/etc/liferay/lxc/ext-init-metadata"
	fi

	if [ ! -n "${LIFERAY_ROUTES_DXP}" ]
	then
		LIFERAY_ROUTES_DXP="/etc/liferay/lxc/dxp-metadata"
	fi

	echo "OAuth Application ERC: ${LIFERAY_BATCH_OAUTH_APP_ERC}"
	echo ""

	local lxc_dxp_main_domain=$(cat ${LIFERAY_ROUTES_DXP}/com.liferay.lxc.dxp.main.domain)

	if [ ! -n "${lxc_dxp_main_domain}" ]
	then
		lxc_dxp_main_domain=$(cat ${LIFERAY_ROUTES_DXP}/com.liferay.lxc.dxp.mainDomain)
	fi

	local lxc_dxp_server_protocol=$(cat ${LIFERAY_ROUTES_DXP}/com.liferay.lxc.dxp.server.protocol)
	local oauth2_client_id=$(cat ${LIFERAY_ROUTES_CLIENT_EXTENSION}/${LIFERAY_BATCH_OAUTH_APP_ERC}.oauth2.headless.server.client.id)
	local oauth2_client_secret=$(cat ${LIFERAY_ROUTES_CLIENT_EXTENSION}/${LIFERAY_BATCH_OAUTH_APP_ERC}.oauth2.headless.server.client.secret)
	local oauth2_token_uri=$(cat ${LIFERAY_ROUTES_CLIENT_EXTENSION}/${LIFERAY_BATCH_OAUTH_APP_ERC}.oauth2.token.uri)

	echo "LXC DXP Main Domain: ${lxc_dxp_main_domain}"
	echo "LXC DXP Server Protocol: ${lxc_dxp_server_protocol}"
	echo ""
	echo "OAuth Client ID: ${oauth2_client_id}"
	echo "OAuth Client Secret: ${oauth2_client_secret}"
	echo "OAuth Token URI: ${oauth2_token_uri}"
	echo ""

	local http_code_output=$(mktemp)

	local oauth2_token_response=$(\
		curl \
			-H "Content-type: application/x-www-form-urlencoded" \
			-X POST \
			-d "client_id=${oauth2_client_id}&client_secret=${oauth2_client_secret}&grant_type=client_credentials" \
			-s \
			-w "%output{$http_code_output}%{http_code}" \
			${LIFERAY_BATCH_CURL_OPTIONS} \
			"${lxc_dxp_server_protocol}://${lxc_dxp_main_domain}${oauth2_token_uri}")

	check_http_code "$(cat $http_code_output)" || {
		echo "Unable to get OAuth 2 token response: ${oauth2_token_response}"
		exit 1
	}

	echo "OAuth Token Response: ${oauth2_token_response}"
	echo ""

	local oauth2_access_token=$(jq --raw-output ".access_token" <<< ${oauth2_token_response})

	if [ "${oauth2_access_token}" == "" ]
	then
		echo "Unable to get OAuth 2 access token."

		exit 1
	fi

	if [ -e "/opt/liferay/site-initializer/site-initializer.json" ]
	then
		echo "Processing: /opt/liferay/site-initializer/site-initializer.json"
		echo ""

		local href="/o/headless-site/v1.0/sites/by-external-reference-code/"

		echo "HREF: ${href}"

		local site=$(jq --raw-output '.' /opt/liferay/site-initializer/site-initializer.json)

		echo "Site: ${site}"

		local external_reference_code=$(jq --raw-output ".externalReferenceCode" <<< "${site}")

		local http_code_output=$(mktemp)

		local put_response=$(\
			curl \
				-H "Accept: application/json" \
				-H "Authorization: Bearer ${oauth2_access_token}" \
				-H "Content-Type: multipart/form-data" \
				-X PUT \
				-F "file=@/opt/liferay/site-initializer/site-initializer.zip;type=application/zip" \
				-F "site=${site}" \
				-s \
				-w "%output{$http_code_output}%{http_code}" \
				${LIFERAY_BATCH_CURL_OPTIONS} \
				"${lxc_dxp_server_protocol}://${lxc_dxp_main_domain}${href}${external_reference_code}")

		check_http_code "$(cat $http_code_output)" || {
			echo "Unable to PUT resource: ${put_response}"
			exit 1
		}

		echo "PUT Response: ${put_response}"
		echo ""

		if [ ! -n "${put_response}" ]
		then
			echo "Received empty PUT response. Please check Liferay logs for more information."

			exit 1
		fi
	fi

	find /opt/liferay/batch -type f -name "*.batch-engine-data.json" -print0 2> /dev/null | LC_ALL=C sort --zero-terminated |
	while IFS= read -r -d "" file_name
	do
		echo "Processing: ${file_name}"
		echo ""

		local href=$(jq --raw-output ".actions.createBatch.href" ${file_name})

		if [[ "$href" == "null" ]]
		then
			local class_name=$(jq --raw-output ".configuration.className" ${file_name})

			if [[ "$class_name" == "null" ]]
			then
				echo "Batch data file is missing configuration class name."

				exit 1
			fi

			href="/o/headless-batch-engine/v1.0/import-task/${class_name}"
		fi

		href="${href#*://*/}"

		if [[ ! $href =~ ^/.* ]]
		then
			href="/${href}"
		fi

		echo "HREF: ${href}"

		jq --raw-output ".items" ${file_name} > /tmp/liferay_batch_entrypoint.items.json

		echo "Items: $(</tmp/liferay_batch_entrypoint.items.json)"

		local parameters=$(jq --raw-output '.configuration.parameters | [map_values(. | @uri) | to_entries[] | .key + "=" + .value] | join("&")' ${file_name} 2>/dev/null)

		if [ "${parameters}" != "" ]
		then
			parameters="?${parameters}"
		fi

		echo "Parameters: ${parameters}"

		local http_code_output=$(mktemp)

		local post_response=$(\
			curl \
				-H "Accept: application/json" \
				-H "Authorization: Bearer ${oauth2_access_token}" \
				-H "Content-Type: application/json" \
				-X POST \
				-d @/tmp/liferay_batch_entrypoint.items.json \
				-s \
				-w "%output{$http_code_output}%{http_code}" \
				${LIFERAY_BATCH_CURL_OPTIONS} \
				"${lxc_dxp_server_protocol}://${lxc_dxp_main_domain}${href}${parameters}")

		check_http_code "$(cat $http_code_output)" || {
			echo "Unable to POST resource: ${post_response}"
			exit 1
		}

		echo "POST Response: ${post_response}"
		echo ""

		if [ ! -n "${post_response}" ]
		then
			echo "Received empty POST response. Please check Liferay logs for more information."

			rm /tmp/liferay_batch_entrypoint.items.json

			exit 1
		fi

		local external_reference_code=$(jq --raw-output ".externalReferenceCode" <<< "${post_response}")

		local status=$(jq --raw-output ".executeStatus//.status" <<< "${post_response}")

		until [ "${status}" == "COMPLETED" ] || [ "${status}" == "FAILED" ] || [ "${status}" == "NOT_FOUND" ]
		do
			local http_code_output=$(mktemp)

			local status_response=$(\
				curl \
					-H "accept: application/json" \
					-H "Authorization: Bearer ${oauth2_access_token}" \
					-X 'GET' \
					-s \
					-w "%output{$http_code_output}%{http_code}" \
					${LIFERAY_BATCH_CURL_OPTIONS} \
					"${lxc_dxp_server_protocol}://${lxc_dxp_main_domain}/o/headless-batch-engine/v1.0/import-task/by-external-reference-code/${external_reference_code}")

			check_http_code "$(cat $http_code_output)" || {
				echo "Unable to get status for import task with external reference code ${external_reference_code}: ${status_response}"
				exit 1
			}

			status=$(jq --raw-output '.executeStatus//.status' <<< "${status_response}")

			echo "Execute Status: ${status}"
		done

		rm /tmp/liferay_batch_entrypoint.items.json

		if [ "${status}" == "FAILED" ]
		then
			echo "Batch import task process failed. Please check Liferay logs for more information."
			exit 1
		fi
	done
}

main