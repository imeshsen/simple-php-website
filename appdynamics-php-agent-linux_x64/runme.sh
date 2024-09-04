#!/bin/bash
#
#
# Copyright 2013 AppDynamics.
# All rights reserved.
#
#
# Self Service Install script for AppDynamics PHP agent
#
agentVersionId="24.8.0.1283GA.24.8.0.1283.5c3812dbef65cd935609d09317d19b60588c32a6"
containingDir="$(cd "$(dirname "$0")" && pwd)"

echo "Installing AppDynamics PHP agent: ${agentVersionId}"

varFileBaseName="installVars"
varFile="${containingDir}/${varFileBaseName}"

rpmBaseName=""
tarballBaseName="appdynamics-php-agent-linux_x64.tar.bz2"
validTlsVersions=("TLSv1.2" "TLSv1.3")

if [ ! -r "${varFile}" ] ; then
    echo "Unable to find install variables at: ${varFile}" >&2
    echo "Please contact customer support." >&2
    exit 1
fi

. "${varFile}"

if [ -z "${APPD_CONF_CONTROLLER_HOST}" ] ; then
    echo "${varFileBaseName} did not set APPD_CONF_CONTROLLER_HOST!" >&2
    echo "Please contact customer support" >&2
    exit 1
fi

if [ -z "${APPD_CONF_CONTROLLER_PORT}" ] ; then
    echo "${varFileBaseName} did not set APPD_CONF_CONTROLLER_PORT!" >&2
    echo "Please contact customer support" >&2
    exit 1
fi

if [ -z "${APPD_CONF_ACCOUNT_NAME}" -a -n "${APPD_CONF_ACCESS_KEY}" ] ; then
    echo "${varFileBaseName} set APPD_CONF_ACCESS_KEY, but not APPD_CONF_ACCOUNT_NAME." >&2
    echo "Please contact customer support" >&2
    exit 1
fi

if [ -z "${APPD_CONF_ACCESS_KEY}" -a -n "${APPD_CONF_ACCOUNT_NAME}" ] ; then
    echo "${varFileBaseName} set APPD_CONF_ACCOUNT_NAME, but not APPD_CONF_ACCESS_KEY." >&2
    echo "Please contact customer support" >&2
    exit 1
fi

if [ -z "${APPD_CONF_HTTP_PROXY_HOST}" -a -n "${APPD_CONF_HTTP_PROXY_PORT}" ] ; then
    echo "${varFileBaseName} set APPD_CONF_HTTP_PROXY_PORT, but not APPD_CONF_HTTP_PROXY_HOST." >&2
    echo "Please contact customer support" >&2
    exit 1
fi

if [ -z "${APPD_CONF_HTTP_PROXY_PORT}" -a -n "${APPD_CONF_HTTP_PROXY_HOST}" ] ; then
    echo "${varFileBaseName} set APPD_CONF_HTTP_PROXY_HOST, but not APPD_CONF_HTTP_PROXY_PORT." >&2
    echo "Please contact customer support" >&2
    exit 1
fi

if [ -z "${APPD_CONF_HTTP_PROXY_USER}" -a -n "${APPD_CONF_HTTP_PROXY_PASSWORD_FILE}" ] ; then
    echo "${varFileBaseName} set APPD_CONF_HTTP_PROXY_PASSWORD_FILE, but not APPD_CONF_HTTP_PROXY_USER." >&2
    echo "Please contact customer support" >&2
    exit 1
fi

if [ -z "${APPD_CONF_HTTP_PROXY_PASSWORD_FILE}" -a -n "${APPD_CONF_HTTP_PROXY_USER}" ] ; then
    echo "${varFileBaseName} set APPD_CONF_HTTP_PROXY_USER, but not APPD_CONF_HTTP_PROXY_PASSWORD_FILE." >&2
    echo "Please contact customer support" >&2
    exit 1
fi

if [ -z "${APPD_CONF_TCP_COMM_HOST}" -a -n "${APPD_CONF_TCP_COMM_PORT}" ] ; then
    echo "${varFileBaseName} set APPD_CONF_TCP_COMM_PORT, but not APPD_CONF_TCP_COMM_HOST." >&2
    echo "Please contact customer support" >&2
    exit 1
fi

if [ -z "${APPD_CONF_TCP_COMM_PORT}" -a -n "${APPD_CONF_TCP_COMM_HOST}" ] ; then
    echo "${varFileBaseName} set APPD_CONF_TCP_COMM_HOST, but not APPD_CONF_TCP_COMM_PORT." >&2
    echo "Please contact customer support" >&2
    exit 1
fi

if [ -z "${APPD_CONF_TLS_VERSION}" ] ; then
    APPD_CONF_TLS_VERSION="TLSv1.2"
fi

if [ -n "$APPD_CONF_TLS_VERSION" ]; then
    valid_tls=false
    for version in "${validTlsVersions[@]}"; do
        if [[ "$version" == "$APPD_CONF_TLS_VERSION" ]]; then
            valid_tls=true
            break
        fi
    done

    if [[ "$valid_tls" == false ]]; then
        echo "TLS version '$APPD_CONF_TLS_VERSION' is not supported. Supported TLS versions are: ${validTlsVersions[@]}"
        exit 1
    fi

fi



rpmFileName="${containingDir}/${rpmBaseName}"
tarFileName="${containingDir}/${tarballBaseName}"

if [ ! -f "${rpmFileName}" -a ! -f "${tarFileName}" ]; then
    echo "Unable to find rpm file ( '${rpmFileName}' ) or tar file ( '${tarFileName}' )" >&2
    echo "Please contact customer support" >&2
    exit 1
fi

[ -n "${APPD_CONF_CONTROLLER_HOST}" ] && export APPD_CONF_CONTROLLER_HOST
[ -n "${APPD_CONF_CONTROLLER_PORT}" ] && export APPD_CONF_CONTROLLER_PORT
[ -n "${APPD_CONF_APP}" ] && export APPD_CONF_APP
[ -n "${APPD_CONF_TIER}" ] && export APPD_CONF_TIER
[ -n "${APPD_CONF_NODE}" ] && export APPD_CONF_NODE
[ -n "${APPD_CONF_ACCOUNT_NAME}" ] && export APPD_CONF_ACCOUNT_NAME
[ -n "${APPD_CONF_ACCESS_KEY}" ] && export APPD_CONF_ACCESS_KEY
[ -n "${APPD_CONF_SSL_ENABLED}" ] && export APPD_CONF_SSL_ENABLED
[ -n "${APPD_CONF_HTTP_PROXY_HOST}" ] && export APPD_CONF_HTTP_PROXY_HOST
[ -n "${APPD_CONF_HTTP_PROXY_PORT}" ] && export APPD_CONF_HTTP_PROXY_PORT
[ -n "${APPD_CONF_HTTP_PROXY_USER}" ] && export APPD_CONF_HTTP_PROXY_USER
[ -n "${APPD_CONF_HTTP_PROXY_PASSWORD_FILE}" ] && export APPD_CONF_HTTP_PROXY_PASSWORD_FILE
[ -n "${APPD_CONF_LOG_DIR}" ] && export APPD_CONF_LOG_DIR
[ -n "${APPD_CONF_PROXY_CTRL_DIR}" ] && export APPD_CONF_PROXY_CTRL_DIR
[ -n "${APPD_CONF_TLS_VERSION}" ] && export APPD_CONF_TLS_VERSION
[ -n "${APPD_CONF_TCP_COMM_HOST}" ] && export APPD_CONF_TCP_COMM_HOST
[ -n "${APPD_CONF_TCP_COMM_PORT}" ] && export APPD_CONF_TCP_COMM_PORT
[ -n "${APPD_CONF_TCP_REPORTING_PORT}" ] && export APPD_CONF_TCP_REPORTING_PORT
[ -n "${APPD_CONF_TCP_REQUEST_PORT}" ] && export APPD_CONF_TCP_REQUEST_PORT
[ -n "${APPD_CONF_TCP_PORT_RANGE}" ] && export APPD_CONF_TCP_PORT_RANGE
[ -n "${APPD_CONF_CURVE_ENABLED}" ] && export APPD_CONF_CURVE_ENABLED
[ -n "${APPD_CONF_CURVE_ZAP_ENABLED}" ] && export APPD_CONF_CURVE_ZAP_ENABLED
[ -n "${APPD_CONF_NODE_REUSE}" ] && export APPD_CONF_NODE_REUSE


if [ -f "${rpmFileName}" ]; then
    rpm -i "${rpmFileName}"
else
    tar -xjf "${tarFileName}" --overwrite --strip-components 1 -C "${containingDir}"
    APPD_AUTO_MODE="install" \
        "${containingDir}/install.sh"
fi
