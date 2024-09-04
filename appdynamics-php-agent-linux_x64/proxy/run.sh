#!/bin/sh
#
#
# Copyright 2013 AppDynamics.
# All rights reserved.
#
#

## Lines that begin with ## will be stripped from this file as part of the
## agent build process.

# BASE_DIR refers to the directory containing the runProxy
BASE_DIR="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

runProxyScript=${BASE_DIR}/runProxy
runProxyScriptDir=${BASE_DIR}

jreDir=
# If JAVA_HOME is set, jreDir gets picked up from there
if [ -n "${JAVA_HOME}" ] ; then
    jreDir="${JAVA_HOME}"
fi

verbose=

# If environment variable not set, default to /tmp/appd
agentBaseDir=/tmp/appd
if [ ! -z "${APPDYNAMICS_AGENT_BASE_DIR}" ] ; then
    agentBaseDir=${APPDYNAMICS_AGENT_BASE_DIR}
fi

# If environment variable not set, default to ${agentBaseDir}/run
proxyRunDir=${agentBaseDir}/run
if [ ! -z "${APPDYNAMICS_PROXY_RUN_DIR}" ] ; then
    proxyRunDir=${APPDYNAMICS_PROXY_RUN_DIR}
fi
proxy_pid_file=${proxyRunDir}/proxy.pid

# If environment variable not set, default to ${proxyRunDir}/comm
commDir=${proxyRunDir}/comm
if [ ! -z "${APPDYNAMICS_PROXY_CONTROL_PATH}" ] ; then
    commDir=${APPDYNAMICS_PROXY_CONTROL_PATH}
fi

# If environment variable not set, default to ${agentBaseDir}/logs
logsDir=${agentBaseDir}/logs
if [ ! -z "${APPDYNAMICS_LOGS_DIR}" ] ; then
    logsDir=${APPDYNAMICS_LOGS_DIR}
fi

# Setting up curve variables
if [ -n "${APPDYNAMICS_CURVE_ENABLED}" ] ; then
    certsDir=${agentBaseDir}/certs
    curvePublicKeyDir=${certsDir}/public
    if [ ! -z "${APPDYNAMICS_CURVE_PUBLIC_KEY_DIR}" ] ; then
        curvePublicKeyDir=${APPDYNAMICS_CURVE_PUBLIC_KEY_DIR}
    fi
    curveSecretKeyDir=${certsDir}/secret
    if [ ! -z "${APPDYNAMICS_CURVE_SECRET_KEY_DIR}" ] ; then
        curveSecretKeyDir=${APPDYNAMICS_CURVE_SECRET_KEY_DIR}
    fi

    curveProxySecretFile=${curveSecretKeyDir}/proxy.key_secret
    if [ ! -z "${APPDYNAMICS_CURVE_PROXY_SECRET_KEY_FILE}" ] ; then
        curveProxySecretFile=${APPDYNAMICS_CURVE_PROXY_SECRET_KEY_FILE}
    fi
    # Try to create the directory for file
    if [ -z "${curveProxySecretFile##*/*}" ]; then
        mkdir -p -m 777 ${curveProxySecretFile%/*}
    fi
    curveProxyPublicFile=${curvePublicKeyDir}/proxy.key
    if [ ! -z "${APPDYNAMICS_CURVE_PROXY_PUBLIC_KEY_FILE}" ] ; then
        curveProxyPublicFile=${APPDYNAMICS_CURVE_PROXY_PUBLIC_KEY_FILE}
    fi
    # Try to create the directory for file
    if [ -z "${curveProxyPublicFile##*/*}" ]; then
        mkdir -p -m 777 ${curveProxyPublicFile%/*}
    fi
fi

stop_proxy() {
    # read proxy's pid from proxy_pid_file and raise an interrupt signal
    proxy_pid=`cat ${proxy_pid_file}`
    kill -15 ${proxy_pid}
}

usage() {

cat << EOF
Usage: `basename $0`
Options:
  -j <dir>, --jre-dir=<dir>             Specifies root JRE directory
  -v, --verbose                         Enable verbose output
  -h, --help                            Show this message
  -s, --stop                            Stops the proxy

Example: $0 -j /usr
Note: Please use quotes for the entries wherever applicable.

EOF
}

optspec=":j:svh-:"
while getopts "$optspec" optchar; do
    case "${optchar}" in
        -)
            case "${OPTARG}" in
                help)
                    usage
                    exit 0
                    ;;
                jre-dir=*)
                    jreDir=${OPTARG#*=}
                    ;;
                verbose)
                    verbose=yes
                    ;;
                stop)
                    stop_proxy
                    exit 0
                    ;;
                *)
                    echo "Invalid option: '--${OPTARG}'" >&2
                    ok=0
                    exit 1
                    ;;
            esac;;
        j)
            jreDir=${OPTARG#*=}
            ;;
        v)
            verbose=yes
            ;;
        h)
            usage
            exit 0
            ;;
        s)
            stop_proxy
            exit 0
            ;;
        *)
            if [ "$OPTERR" != 1 ] || [ `echo $optspec | cut -c1-1` = ":" ]; then
                echo "Invalid option: '-${OPTARG}'" >&2
                ok=0
                exit 1
            fi
            ;;
    esac
done

mkdir -p -m 777 "$proxyRunDir"
mkdir -p -m 777 "$commDir"
mkdir -p -m 777 "$logsDir"

runCmd=

prepareCmdLine() {
    set -- ${runProxyScript}
    if [ -n "${jreDir}" ] ; then
        set -- "$@" --jre-dir=${jreDir}
    fi
    set -- "$@" --proxy-dir=${runProxyScriptDir}
    set -- "$@" --proxy-runtime-dir=${proxyRunDir}
    if [ -n "${verbose}" ]  ; then
        set -- "$@" -v
    fi

    # Append these variables only if the corresponding environment variable exists
    if [ -n "${APPDYNAMICS_MAX_HEAP_SIZE}" ] ; then
        set -- "$@" --max-heap-size=${APPDYNAMICS_MAX_HEAP_SIZE}
    fi
    if [ -n "${APPDYNAMICS_MIN_HEAP_SIZE}" ] ; then
        set -- "$@" --min-heap-size=${APPDYNAMICS_MIN_HEAP_SIZE}
    fi
    if [ -n "${APPDYNAMICS_MAX_PERM_SIZE}" ] ; then
        set -- "$@" --max-perm-size=${APPDYNAMICS_MAX_PERM_SIZE}
    fi
    if [ -n "${APPDYNAMICS_HTTP_PROXY_HOST}" ] ; then
        set -- "$@" --http-proxy-host=${APPDYNAMICS_HTTP_PROXY_HOST}
    fi
    if [ -n "${APPDYNAMICS_HTTP_PROXY_PORT}" ] ; then
        set -- "$@" --http-proxy-port=${APPDYNAMICS_HTTP_PROXY_PORT}
    fi
    if [ -n "${APPDYNAMICS_HTTP_PROXY_USER}" ] ; then
        set -- "$@" --http-proxy-user=${APPDYNAMICS_HTTP_PROXY_USER}
    fi
    if [ -n "${APPDYNAMICS_HTTP_PROXY_PASSWORD_FILE}" ] ; then
        set -- "$@" --http-proxy-password-file=${APPDYNAMICS_HTTP_PROXY_PASSWORD_FILE}
    fi
    if [ -n "${APPDYNAMICS_START_SUSPENDED}" ] ; then
        set -- "$@" --start-suspended=${APPDYNAMICS_START_SUSPENDED}
    fi
    if [ -n "${APPDYNAMICS_PROXY_DEBUG_PORT}" ] ; then
        set -- "$@" --proxy-debug-port=${APPDYNAMICS_PROXY_DEBUG_PORT}
    fi
    if [ -n "${APPDYNAMICS_DEBUG_OPT}" ] ; then
        set -- "$@" --debug-opt=${APPDYNAMICS_DEBUG_OPT}
    fi
    if [ -n "${APPDYNAMICS_AGENT_TYPE}" ] ; then
        set -- "$@" --agent-type=${APPDYNAMICS_AGENT_TYPE}
    fi

    set -- "$@" ${commDir}
    set -- "$@" ${logsDir}

    if [ -n "${APPDYNAMICS_AGENT_CONTAINER_ENABLED}" ] ; then
        set -- "$@" -Dappdynamics.container.enabled=${APPDYNAMICS_AGENT_CONTAINER_ENABLED}
    fi
    if [ -n "${APPDYNAMICS_AGENT_UNIQUE_HOST_ID}" ] ; then
        set -- "$@" -Dappdynamics.agent.uniqueHostId=${APPDYNAMICS_AGENT_UNIQUE_HOST_ID}
    fi
    if [ -n "${APPDYNAMICS_TCP_COMM_PORT}" ] ; then
        set -- "$@" -Dcommtcp=${APPDYNAMICS_TCP_COMM_PORT}
        if [ -n "${APPDYNAMICS_TCP_COMM_HOST}" ] ; then
            set -- "$@" -Dappdynamics.proxy.commtcphost=${APPDYNAMICS_TCP_COMM_HOST}
        fi
        if [ -n "${APPDYNAMICS_TCP_PORT_RANGE}" ] ; then
            set -- "$@" -Dappdynamics.proxy.commportrange=${APPDYNAMICS_TCP_PORT_RANGE}
        fi
    fi
    if [ -n "${APPDYNAMICS_CURVE_ENABLED}" ] ; then
        set -- "$@" -Dappdynamics.proxy.curveenabled=yes
        set -- "$@" -Dappdynamics.proxy.curvesecretfile=${curveProxySecretFile}
        set -- "$@" -Dappdynamics.proxy.curvepublicfile=${curveProxyPublicFile}
        if [ -n "${APPDYNAMICS_CURVE_ZAP_ENABLED}" ] ; then
            set -- "$@" -Dappdynamics.proxy.curvepublickeydir=${curvePublicKeyDir}
        fi
    fi
    set -- "$@" -Dappdynamics.proxy.shutdownservice.enabled=yes
    runCmd=$@
}

prepareCmdLine


if [ -n "${verbose}" ]  ; then
    echo ${runCmd}
fi

umask 011

echo $$ > ${proxy_pid_file}
exec $runCmd