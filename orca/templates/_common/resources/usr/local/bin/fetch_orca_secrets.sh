#!/bin/bash

function check_usage {
	if [ "${ORCA_DEVELOPMENT_MODE}" == "true" ]
	then
		ORCA_VAULT_SERVICE_PASSWORD="development"
	fi

	if [ ! -n "${ORCA_VAULT_ADDRESSES}" ] || [ ! -n "${ORCA_VAULT_SERVICE_PASSWORD}" ]
	then
		echo "Set the environment variables ORCA_VAULT_ADDRESSES and ORCA_VAULT_SERVICE_PASSWORD."

		exit 1
	fi
}

function get_token {
	local round=0

	for round in $(seq 30)
	do
		echo "Fetching vault login token (${round}/30)."

		local token=$(curl --fail --request POST --silent "http://${ORCA_VAULT_ADDRESSES}/v1/auth/userpass-${1}/login/${1}" --data "{\"password\": \"${ORCA_VAULT_SERVICE_PASSWORD}\"}")

		if [ -n "${token}" ]
		then
			break
		fi

		sleep 3
	done

	if [ ! -n "${token}" ]
	then
		echo "Unable to fetch vault login token."

		exit 1
	fi

	token=${token##*client_token\":\"}
	token=${token%%\"*}

	echo "${token}"
}

function load_secrets {
	mkdir -p /tmp/orca-secrets

	local token="${1}"
	shift

	for secret in "${@}"
	do
		local round=0

		for round in $(seq 30)
		do
			echo "Fetching secret \"${secret}\" (${round}/40)."

			local password=$(curl --fail --header "X-Vault-Token: ${token}" --request GET --silent "http://${ORCA_VAULT_ADDRESSES}/v1/secret/data/${secret}")

			local exit_code="${?}"

			if [ "${exit_code}" -gt 0 ]
			then
				echo "Unable to fetch secret \"${secret}\": ${exit_code}."

				sleep 3
			fi

			if [ -n "${password}" ]
			then
				echo "Fetched secret \"${secret}\"."

				break
			fi

			sleep 3
		done

		if [ ! -n "${password}" ]
		then
			echo "Unable to fetch secret \"${secret}\"."

			exit 1
		fi

		password=${password##*password\":\"}
		password=${password%%\"*}

		echo "${password}" > "/tmp/orca-secrets/${secret}"

		chmod 600 "/tmp/orca-secrets/${secret}"
	done
}

function main {
	local service="${1}"
	shift

	check_usage

	wait_for_vault

	load_secrets $(get_token "${service}") "${@}"

	unset ORCA_VAULT_TOKEN
}

function wait_for_vault {
	echo "Connecting to vault ${ORCA_VAULT_ADDRESSES}."

	while true
	do
		for ORCA_VAULT_ADDRESSES in ${ORCA_VAULT_ADDRESSES//,/ }
		do
			if ( curl --max-time 3 --silent "http://${ORCA_VAULT_ADDRESSES}/v1/sys/health" | grep "\"sealed\":false" &>/dev/null)
			then
				echo "Vault ${ORCA_VAULT_ADDRESSES} is available."

				return
			fi
		done

		echo "Waiting for at least one vault to become available."

		sleep 3
	done
}

main "${@}"