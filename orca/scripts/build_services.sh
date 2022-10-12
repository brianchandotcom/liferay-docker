#!/bin/bash

set -e

function add_services {
	write_docker_compose 0 "services:"

	if [ ! -n "${ORCA_HOST}" ]
	then
		ORCA_HOST=$(hostname)
	fi

	local host_config=$(query_configuration ".hosts.${ORCA_HOST}")

	if [ ! -n "${host_config}" ]
	then
		ORCA_HOST="localhost"

		host_config=$(query_configuration ".hosts.${ORCA_HOST}")

		if [ ! -n "${host_config}" ]
		then
			echo "Unable to find a matching host in the configuration. Set the environment variable ORCA_HOST."

			exit 1
		fi
	fi

	for SERVICE in $(yq ".hosts.${ORCA_HOST}.services" < "${CONFIG_FILE}" | grep -v "  .*" | sed "s/-[ ]//" | sed "s/:.*//")
	do
		SERVICE_HOST="${SERVICE}-${ORCA_HOST}"

		echo "Building ${SERVICE}."

		rm -fr docker-build
		mkdir -p docker-build

		cp -a templates/_common/* docker-build
		cp -a templates/${SERVICE}/* docker-build

		build_$(echo ${SERVICE} | sed -e "s/-/_/")

		rm -fr docker-build
	done
}

function build_antivirus {
	docker_build antivirus

	write_docker_compose 1 "${SERVICE}:"
	write_docker_compose 1 "    container_name: ${SERVICE}"
	write_docker_compose 1 "    hostname: ${SERVICE_HOST}"
	write_docker_compose 1 "    image: antivirus:${VERSION}"
	write_docker_compose 1 "    ports:"
	write_docker_compose 1 "        - \"3310:3310\""
}

function build_backup {
	docker_build backup

	write_docker_compose 1 "${SERVICE}:"
	write_docker_compose 1 "    container_name: ${SERVICE}"
	write_docker_compose 1 "    environment:"
	write_docker_compose 1 "        - ORCA_BACKUP_CRON_EXPRESSION=0 */4 * * *"
	write_docker_compose 1 "        - ORCA_DB_ADDRESSES=$(query_services db host_port 3306)"
	write_docker_compose 1 "        - ORCA_VAULT_ADDRESSES=$(query_services vault host_port 8200)"
	write_docker_compose 1 "        - ORCA_VAULT_TOKEN=\${ORCA_VAULT_TOKEN_backup:-}"
	write_docker_compose 1 "    hostname: ${SERVICE_HOST}"
	write_docker_compose 1 "    image: backup:${VERSION}"
	write_docker_compose 1 "    volumes:"
	write_docker_compose 1 "        - /opt/liferay/backups:/opt/liferay/backups"
	write_docker_compose 1 "        - /opt/liferay/shared-volume:/opt/liferay/shared-volume"
}

function build_ci {
	docker_build ci

	write_docker_compose 1 "${SERVICE}:"
	write_docker_compose 1 "    container_name: ${SERVICE}"
	write_docker_compose 1 "    hostname: ${SERVICE_HOST}"
	write_docker_compose 1 "    image: ci:${VERSION}"
	write_docker_compose 1 "    ports:"
	write_docker_compose 1 "        - \"9080:8080\""
	write_docker_compose 1 "    volumes:"
	write_docker_compose 1 "        - /opt/liferay/jenkins-home:/var/jenkins_home"
}

function build_db {
	docker_build db

	write_docker_compose 1 "${SERVICE}:"
	write_docker_compose 1 "    container_name: ${SERVICE}"
	write_docker_compose 1 "    environment:"
	write_docker_compose 1 "        - MARIADB_DATABASE=lportal"
	write_docker_compose 1 "        - MARIADB_EXTRA_FLAGS=--character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci --wsrep_provider_options=ist.recv_addr=${host_ip}:4568;ist.recv_bind=0.0.0.0:4568 --wsrep_node_incoming_address=${host_ip} --wsrep_sst_receive_address=${host_ip}"
	write_docker_compose 1 "        - MARIADB_GALERA_CLUSTER_ADDRESS=gcomm://$(query_services db host_port 4567 true)"
	write_docker_compose 1 "        - MARIADB_GALERA_CLUSTER_BOOTSTRAP=\${ORCA_DB_SKIP_WAIT:-}"
	write_docker_compose 1 "        - MARIADB_GALERA_CLUSTER_NAME=liferay-db"
	write_docker_compose 1 "        - MARIADB_GALERA_MARIABACKUP_PASSWORD_FILE=/tmp/orca-secrets/mysql_backup_password"
	write_docker_compose 1 "        - MARIADB_GALERA_MARIABACKUP_USER=orca_mariabackup"
	write_docker_compose 1 "        - MARIADB_GALERA_NODE_ADDRESS=$(query_configuration .hosts.${ORCA_HOST}.ip ${SERVICE_HOST})"
	write_docker_compose 1 "        - MARIADB_PASSWORD_FILE=/tmp/orca-secrets/mysql_liferay_password"
	write_docker_compose 1 "        - MARIADB_ROOT_HOST=localhost"
	write_docker_compose 1 "        - MARIADB_ROOT_PASSWORD_FILE=/tmp/orca-secrets/mysql_root_password"
	write_docker_compose 1 "        - MARIADB_USER=lportal"
	write_docker_compose 1 "        - ORCA_DB_ADDRESSES=$(query_services db host_port 3306 true)"
	write_docker_compose 1 "        - ORCA_DB_SKIP_WAIT=\${ORCA_DB_SKIP_WAIT:-}"
	write_docker_compose 1 "        - ORCA_VAULT_ADDRESSES=$(query_services vault host_port 8200)"
	write_docker_compose 1 "        - ORCA_VAULT_TOKEN=\${ORCA_VAULT_TOKEN_db:-}"
	write_docker_compose 1 "    hostname: ${SERVICE_HOST}"
	write_docker_compose 1 "    image: db:${VERSION}"
	write_docker_compose 1 "    ports:"
	write_docker_compose 1 "        - \"3306:3306\""
	write_docker_compose 1 "        - \"4444:4444\""
	write_docker_compose 1 "        - \"4567:4567\""
	write_docker_compose 1 "        - \"4568:4568\""
	write_docker_compose 1 "    volumes:"
	write_docker_compose 1 "        - /opt/liferay/db-data:/bitnami/mariadb"
}

function build_liferay {
	if [ -e configs/liferay-license.xml ]
	then
		mkdir -p "docker-build/resources/opt/liferay/deploy"

		cp configs/liferay-license.xml docker-build/resources/opt/liferay/deploy/license.xml
	else
		echo "Copy a valid Liferay DXP license to configs/liferay-license.xml before running this script."

		exit 1
	fi

	if [ -d /opt/liferay/shared-volume/deploy ]
	then
		echo "Copying the following files to deploy:"

		ls -l /opt/liferay/shared-volume/deploy

		cp /opt/liferay/shared-volume/deploy/* docker-build/resources/opt/liferay/deploy/
	fi

	if [ $(find "configs/" -maxdepth 1 -type f -name "liferay-*.zip" | wc -l) == 1 ]
	then
		echo "Copying hotfix to deploy: $(ls configs/liferay-*.zip)"

		mkdir -p docker-build/resources/opt/liferay/patching-tool/patches

		cp configs/liferay-*.zip docker-build/resources/opt/liferay/patching-tool/patches
	fi

	docker_build liferay

	local search_addresses=$(query_services search host_port 9200)

	write_docker_compose 1 "${SERVICE}:"
	write_docker_compose 1 "    container_name: ${SERVICE}"
	write_docker_compose 1 "    environment:"

	if [ -n "$(query_services liferay host_port 8080 true)" ]
	then
		write_docker_compose 2 "    - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_ENABLED=true"
		write_docker_compose 2 "    - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_CHANNEL_PERIOD_LOGIC_PERIOD_NAME_PERIOD_CONTROL=control-channel-${ORCA_HOST}"
		write_docker_compose 2 "    - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_CHANNEL_PERIOD_LOGIC_PERIOD_NAME_PERIOD_TRANSPORT_PERIOD_NUMBER0=transport-channel-logic-${ORCA_HOST}"
		write_docker_compose 2 "    - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_CHANNEL_PERIOD_PROPERTIES_PERIOD_CONTROL=/opt/liferay/cluster-link-tcp.xml"
		write_docker_compose 2 "    - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_CHANNEL_PERIOD_PROPERTIES_PERIOD_TRANSPORT_PERIOD__NUMBER0_=/opt/liferay/cluster-link-tcp.xml"
		write_docker_compose 2 "    - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_AUTODETECT_PERIOD_ADDRESS="
	fi

	write_docker_compose 1 "        - LIFERAY_CONFIGURATION_PERIOD_OVERRIDE_PERIOD_COM_PERIOD_LIFERAY_PERIOD_ANTIVIRUS_PERIOD_CLAMD_PERIOD_SCANNER_PERIOD_INTERNAL_PERIOD_CONFIGURATION_PERIOD__UPPERCASEC_LAMD_UPPERCASEA_NTIVIRUS_UPPERCASES_CANNER_UPPERCASEC_ONFIGURATION_UNDERLINE_HOSTNAME=\"$(query_services antivirus host_port)\""
	write_docker_compose 1 "        - LIFERAY_CONFIGURATION_PERIOD_OVERRIDE_PERIOD_COM_PERIOD_LIFERAY_PERIOD_ANTIVIRUS_PERIOD_CLAMD_PERIOD_SCANNER_PERIOD_INTERNAL_PERIOD_CONFIGURATION_PERIOD__UPPERCASEC_LAMD_UPPERCASEA_NTIVIRUS_UPPERCASES_CANNER_UPPERCASEC_ONFIGURATION_UNDERLINE_PORT=I\"3310\""
	write_docker_compose 1 "        - LIFERAY_CONFIGURATION_PERIOD_OVERRIDE_PERIOD_COM_PERIOD_LIFERAY_PERIOD_ANTIVIRUS_PERIOD_CLAMD_PERIOD_SCANNER_PERIOD_INTERNAL_PERIOD_CONFIGURATION_PERIOD__UPPERCASEC_LAMD_UPPERCASEA_NTIVIRUS_UPPERCASES_CANNER_UPPERCASEC_ONFIGURATION_UNDERLINE_TIMEOUT=I\"10000\""
	write_docker_compose 1 "        - LIFERAY_CONFIGURATION_PERIOD_OVERRIDE_PERIOD_COM_PERIOD_LIFERAY_PERIOD_PORTAL_PERIOD_SEARCH_PERIOD_ELASTICSEARCH_NUMBER7__PERIOD_CONFIGURATION_PERIOD__UPPERCASEE_LASTICSEARCH_UPPERCASEC_ONFIGURATION_UNDERLINE_NETWORK_UPPERCASEH_OST_UPPERCASEA_DDRESSES=\"${search_addresses}\""
	write_docker_compose 1 "        - LIFERAY_CONFIGURATION_PERIOD_OVERRIDE_PERIOD_COM_PERIOD_LIFERAY_PERIOD_PORTAL_PERIOD_SEARCH_PERIOD_ELASTICSEARCH_NUMBER7__PERIOD_CONFIGURATION_PERIOD__UPPERCASEE_LASTICSEARCH_UPPERCASEC_ONFIGURATION_UNDERLINE_OPERATION_UPPERCASEM_ODE=\"REMOTE\""
	write_docker_compose 1 "        - LIFERAY_CONFIGURATION_PERIOD_OVERRIDE_PERIOD_COM_PERIOD_LIFERAY_PERIOD_PORTAL_PERIOD_SEARCH_PERIOD_ELASTICSEARCH_NUMBER7__PERIOD_CONFIGURATION_PERIOD__UPPERCASEE_LASTICSEARCH_UPPERCASEC_ONFIGURATION_UNDERLINE_PRODUCTION_UPPERCASEM_ODE_UPPERCASEE_NABLED=B\"true\""
	write_docker_compose 1 "        - LIFERAY_CONFIGURATION_PERIOD_OVERRIDE_PERIOD_COM_PERIOD_LIFERAY_PERIOD_PORTAL_PERIOD_STORE_PERIOD_FILE_PERIOD_SYSTEM_PERIOD_CONFIGURATION_PERIOD__UPPERCASEA_DVANCED_UPPERCASEF_ILE_UPPERCASES_YSTEM_UPPERCASES_TORE_UPPERCASEC_ONFIGURATION_UNDERLINE_ROOT_UPPERCASED_IR=\"/opt/liferay/shared-volume/document-library\""
	write_docker_compose 1 "        - LIFERAY_DISABLE_TRIAL_LICENSE=true"
	write_docker_compose 1 "        - LIFERAY_DL_PERIOD_STORE_PERIOD_ANTIVIRUS_PERIOD_ENABLED=true"
	write_docker_compose 1 "        - LIFERAY_DL_PERIOD_STORE_PERIOD_IMPL=com.liferay.portal.store.file.system.AdvancedFileSystemStore"
	write_docker_compose 1 "        - LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_DRIVER_UPPERCASEC_LASS_UPPERCASEN_AME=org.mariadb.jdbc.Driver"
	write_docker_compose 1 "        - LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD_FILE=/tmp/orca-secrets/mysql_liferay_password"
	write_docker_compose 1 "        - LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_URL=jdbc:mariadb://$(query_configuration .hosts.${ORCA_HOST}.configuration.liferay.db db-${ORCA_HOST})/lportal?characterEncoding=UTF-8&dontTrackOpenResources=true&holdResultsOpenOverStatementClose=true&serverTimezone=GMT&useFastDateParsing=false&useUnicode=true&useSSL=false"
	write_docker_compose 1 "        - LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME=lportal"
	write_docker_compose 1 "        - LIFERAY_JVM_OPTS=-Djgroups.bind_addr=${SERVICE_HOST} -Djgroups.external_addr=$(query_configuration .hosts.${ORCA_HOST}.ip ${SERVICE_HOST})"
	write_docker_compose 1 "        - LIFERAY_SCHEMA_PERIOD_MODULE_PERIOD_BUILD_PERIOD_AUTO_PERIOD_UPGRADE=true"
	write_docker_compose 1 "        - LIFERAY_SETUP_PERIOD_DATABASE_PERIOD_JAR_PERIOD_URL_OPENBRACKET_COM_PERIOD_MYSQL_PERIOD_CJ_PERIOD_JDBC_PERIOD__UPPERCASED_RIVER_CLOSEBRACKET_=https://repo1.maven.org/maven2/org/mariadb/jdbc/mariadb-java-client/3.0.4/mariadb-java-client-3.0.4.jar"
	write_docker_compose 1 "        - LIFERAY_TOMCAT_AJP_PORT=8009"
	write_docker_compose 1 "        - LIFERAY_TOMCAT_JVM_ROUTE=${ORCA_HOST}"
	write_docker_compose 1 "        - LIFERAY_UPGRADE_PERIOD_DATABASE_PERIOD_AUTO_PERIOD_RUN=true"
	write_docker_compose 1 "        - LIFERAY_WEB_PERIOD_SERVER_PERIOD_DISPLAY_PERIOD_NODE=true"
	write_docker_compose 1 "        - ORCA_LIFERAY_SEARCH_ADDRESSES=${search_addresses}"
	write_docker_compose 1 "        - ORCA_VAULT_ADDRESSES=$(query_services vault host_port 8200)"
	write_docker_compose 1 "        - ORCA_VAULT_TOKEN=\${ORCA_VAULT_TOKEN_liferay:-}"
	write_docker_compose 1 "    hostname: ${SERVICE_HOST}"
	write_docker_compose 1 "    image: liferay:${VERSION}"
	write_docker_compose 1 "    ports:"
	write_docker_compose 1 "        - \"7800:7800\""
	write_docker_compose 1 "        - \"7801:7801\""
	write_docker_compose 1 "        - \"8009:8009\""
	write_docker_compose 1 "        - \"8080:8080\""
	write_docker_compose 1 "    volumes:"
	write_docker_compose 1 "        - /opt/liferay/shared-volume:/opt/liferay/shared-volume"
}

function build_log_proxy {
	docker_build log-proxy

	write_docker_compose 1 "${SERVICE}:"
	write_docker_compose 1 "    command: syslog+udp://$(query_services log-server host_port 514)"
	write_docker_compose 1 "    container_name: ${SERVICE}"
	write_docker_compose 1 "    hostname: ${SERVICE_HOST}"
	write_docker_compose 1 "    image: log-proxy:${VERSION}"
	write_docker_compose 1 "    volumes:"
	write_docker_compose 1 "        - /var/run/docker.sock:/var/run/docker.sock"
}

function build_log_server {
	docker_build log-server

	write_docker_compose 1 "${SERVICE}:"
	write_docker_compose 1 "    command: -F --no-caps"
	write_docker_compose 1 "    container_name: ${SERVICE}"
	write_docker_compose 1 "    hostname: ${SERVICE_HOST}"
	write_docker_compose 1 "    image: log-server:${VERSION}"
	write_docker_compose 1 "    ports:"
	write_docker_compose 1 "        - 514:514/udp"
	write_docker_compose 1 "    volumes:"
	write_docker_compose 1 "        - /opt/liferay/shared-volume/logs:/var/log/syslogng/"
}

function build_search {
	docker_build search

	write_docker_compose 1 "${SERVICE}:"
	write_docker_compose 1 "    container_name: ${SERVICE}"
	write_docker_compose 1 "    environment:"
	write_docker_compose 1 "        - cluster.initial_master_nodes=$(query_services search service_name)"
	write_docker_compose 1 "        - cluster.name=liferay-search"
	write_docker_compose 1 "        - discovery.seed_hosts=$(query_services search host_port 9300 true)"
	write_docker_compose 1 "        - network.publish_host=$(query_configuration .hosts.${ORCA_HOST}.ip ${SERVICE_HOST})"
	write_docker_compose 1 "        - node.name=${SERVICE_HOST}"
	write_docker_compose 1 "        - xpack.ml.enabled=false"
	write_docker_compose 1 "        - xpack.monitoring.enabled=false"
	write_docker_compose 1 "        - xpack.security.enabled=false"
	write_docker_compose 1 "        - xpack.sql.enabled=false"
	write_docker_compose 1 "        - xpack.watcher.enabled=false"
	write_docker_compose 1 "    healthcheck:"
	write_docker_compose 1 "        interval: 40s"
	write_docker_compose 1 "        retries: 3"
	write_docker_compose 1 "        test: curl localhost:9200/_cat/health | grep green"
	write_docker_compose 1 "        timeout: 5s"
	write_docker_compose 1 "    hostname: ${SERVICE_HOST}"
	write_docker_compose 1 "    image: search:${VERSION}"
	write_docker_compose 1 "    mem_limit: 8G"
	write_docker_compose 1 "    ports:"
	write_docker_compose 1 "        - \"9200:9200\""
	write_docker_compose 1 "        - \"9300:9300\""
}

function build_vault {
	docker_build vault

	write_docker_compose 1 "${SERVICE}:"
	write_docker_compose 1 "    container_name: ${SERVICE}"
	write_docker_compose 1 "    environment:"
	write_docker_compose 1 "        - VAULT_RAFT_NODE_ID=${HOST}"
	write_docker_compose 1 "    hostname: ${SERVICE_HOST}"
	write_docker_compose 1 "    image: vault:${VERSION}"
	write_docker_compose 1 "    ports:"
	write_docker_compose 1 "        - \"8200:8200\""
	write_docker_compose 1 "        - \"8201:8201\""
	write_docker_compose 1 "    volumes:"
	write_docker_compose 1 "        - /opt/liferay/vault/data:/opt/liferay/vault/data"
}

function build_web_server {
	docker_build web-server

	write_docker_compose 1 "${SERVICE}:"
	write_docker_compose 1 "    container_name: ${SERVICE}"
	write_docker_compose 1 "    environment:"
	write_docker_compose 1 "        - ORCA_WEB_SERVER_BALANCE_MEMBERS=$(query_services liferay host_port 8009)"
	write_docker_compose 1 "    hostname: ${SERVICE_HOST}"
	write_docker_compose 1 "    image: web-server:${VERSION}"
	write_docker_compose 1 "    ports:"
	write_docker_compose 1 "        - \"80:80\""
}

function check_usage {
	if [ ! -n "${1}" ]
	then
		echo "Usage: ${0} <version>"
		echo ""
		echo "This script reads the following environment variables:"
		echo ""
		echo "    ORCA_CONFIG (optional): Set the name of the configuration. The default value is\"production\"."
		echo "    ORCA_HOST (optional): Set the name of the host to generate the services. The default value is the hostname."
		echo ""
		echo "Set the version number of the generated images as the first parameter to build the images and configuration."
		echo ""
		echo "Example: ${0} 1.0.0"

		exit 1
	fi

	VERSION="${1}"

	check_utils docker docker-compose pwgen yq
}

function check_utils {
	for util in "${@}"
	do
		command -v "${util}" >/dev/null 2>&1 || {echo >&2 "The utility ${util} is not installed."; exit 1;}
	done
}

function choose_configuration {
	if [ ! -n "${ORCA_CONFIG}" ]
	then
		ORCA_CONFIG="production"
	fi

	if [ -e "configs/${ORCA_CONFIG}.yml" ]
	then
		CONFIG_FILE="configs/${ORCA_CONFIG}.yml"

		echo "Using configuration ${CONFIG_FILE}."
	else
		CONFIG_FILE="configs/single_server.yml"

		echo "Using the default single server configuration."
	fi
}

function create_docker_compose_file {
	BUILD_DIR="builds/${VERSION}"
	DOCKER_COMPOSE_FILE="${BUILD_DIR}/docker-compose.yml"

	mkdir -p "${BUILD_DIR}"

	if [ -e "${DOCKER_COMPOSE_FILE}" ]
	then
		rm -f "${DOCKER_COMPOSE_FILE}"
	fi
}

function docker_build {
	docker build \
		--tag "${1}:${VERSION}" \
		docker-build
}

function query_configuration {
	local yq_output=$(yq ${1} < ${CONFIG_FILE})

	if [ "${yq_output}" == "null" ]
	then
		echo "${2}"
	else
		echo "${yq_output}"
	fi
}

function main {
	check_usage ${@}

	choose_configuration

	create_docker_compose_file

	add_services
}

function query_services {
	local list

	for host in $(yq ".hosts" < ${CONFIG_FILE} | grep -v "  .*" | sed "s/-[ ]//" | sed "s/:.*//")
	do
		if [ "${4}" == "true" ] && [ "${host}" == "${ORCA_HOST}" ]
		then
			continue
		fi

		for service in $(yq ".hosts.${host}.services" < "${CONFIG_FILE}" | grep -v "  .*" | sed "s/-[ ]//" | sed "s/:.*//")
		do
			if [ "${service}" == "${1}" ]
			then
				local item

				if [ "${2}" == "host_port" ]
				then
					if [ "${host}" == "localhost" ] || [ "${host}" == "${ORCA_HOST}" ]
					then
						item="${service}-${host}:${3}"
					else
						local host_ip=$(query_configuration .hosts.${host}.ip ${host})

						item="${host_ip}:${3}"
					fi
				elif [ "${2}" == "service_name" ]
				then
					item="${service}-${host}"
				fi

				if [ -n "${list}" ]
				then
					list="${list},${item}"
				else
					list="${item}"
				fi

			fi
		done
	done

	echo "${list}"
}

function write_docker_compose {
	if [ ${1} -eq 0 ]
	then
		echo "${2}" >> ${DOCKER_COMPOSE_FILE}

		return
	fi

	local line=""

	for i in $(seq ${1})
	do
		line="${line}    "
	done

	line="${line}${2}"

	echo "${line}" >> ${DOCKER_COMPOSE_FILE}
}

main ${@}