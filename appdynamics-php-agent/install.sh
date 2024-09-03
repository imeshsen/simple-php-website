#!/bin/sh
#
#
#
# Copyright 2013,2014 AppDynamics.
# All rights reserved.
#
#
# Install script for AppDynamics PHP agent
#

agentVersionId="24.8.0.1283GA.24.8.0.1283.5c3812dbef65cd935609d09317d19b60588c32a6"
ztsFlag=""

if [ -d "${0%/*}" ]; then
    SAVEDIR=`pwd`
    cd "${0%/*}" >/dev/null
    containingDir=$(pwd -P)
    cd "${SAVEDIR}"
else
    containingDir=$(pwd -P)
fi

################################################################################
# Define functions
################################################################################

case $(uname) in
Linux)
    PLATFORM=linux
    statFormatOpt="--format="
    sedCmd="sed -r"
    if [ -f /etc/alpine-release ]; then
        statFormatOpt="-c" 
    fi
    ;;
Darwin)
    PLATFORM=osx
    statFormatOpt="-f"
    sedCmd="sed -E"
    ;;
*)
    echo "Unsupported platform:" $(uname)
    exit 1
    ;;
esac

. $containingDir/phpcheck.sh

log() {
    echo "$@" >> ${install_log}
    if [ -z "${APPD_AUTO_MODE}" ]; then
        echo "$@"
    fi
}

warn() {
  echo "[Warning] $@" >> ${install_log}
  echo "[Warning] $@" >&2
}

log_error() {
    echo "[Error] $@" >> ${install_log}
    echo "[Error] $@" >&2
}

fatal_error() {
    log_error $1
    cat >&2 <<EOF

AppDynamics PHP Agent installation has failed. Please check $install_log for
possible causes. Please also attach it when filing a bug report.
EOF
    if [ "${RPMINSTALL}" =  "true" ]; then
        cat >&2 <<EOF

WARNING: You MUST uninstall the failed RPM first before trying this installation
again.
EOF
        rpmInstallName=`rpm -qa | grep "appdynamics-php${ztsFlag}-agent"`
        if [ -n "${rpmInstallName}" ]; then
            cat >&2 <<EOF

To do this, try using the following command:

    rpm -e ${rpmInstallName}

EOF
        fi
    fi
    exit 1
}

escapeForSedReplacement() {
    local __resultVarName str __result
    __resultVarName="$1"
    str="$2"
    __result=$(echo "$str" | sed 's/[/&]/\\&/g')
    eval $__resultVarName=\'$__result\'
}

checkPathIsAccessible() {
    local __resultVarName currentPath findResult __result
    __resultVarName="$1"
    currentPath="$2"
    __result=""
    while [ "${currentPath}" != "/" ] ; do
        findResult=$(find "${currentPath}" -maxdepth 0 -perm -005 2>/dev/null)
        if [ -z "${findResult}" ] ; then
            __result="${currentPath}"
            break
        fi
        currentPath=$(dirname "${currentPath}")
    done
    eval $__resultVarName="$__result"
}

checkPHPProperty()
{
    local propertyName=$1 ; shift
    local propertyValue=$1 ; shift
    local errorStr="Unable to detect ${propertyName} or empty value specified."
    if [ -n "${propertyValue}" ] ; then
        return
    fi

    if [ ! -x "${php}" ] ; then
        log_error "${errorStr}"
        fatal_error "Unable to find any PHP installation in default locations: ${PATH}"
    fi
    fatal_error "${errorStr}"
}

usage() {

resolvePHPInfo

local phpExtDirHint=${phpExtDir:-"None currently detected"}
local phpConfDirHint=${phpConfDir:-"None currently detected"}
local phpVersionIdHint=${phpVersionId:-"None currently detected"}
local phpThreadSafetyStatusHint=${phpThreadSafetyStatus:-"None currently detected"}
local phpHint="None currently detected"
[ -x "${php}" ] && phpHint=${php}

cat << EOF
Usage: `basename $0` options controller-host controller-port application-name tier-name node-name
Options:
  -a,--account-info           Account name and access key.
                              Use separator @ between name and access key.
                              This needs to be set if the controller is in multi-tenant
                              mode.
  -p,--php-executable-path    File for PHP executable [${phpHint}]
  -e,--php-extension-dir      Directory for PHP extensions [${phpExtDirHint}]
  -i,--php-ini-dir            Directory for PHP INI files [${phpConfDirHint}]
  -v,--php-version            PHP Version, eg: 7.4 [${phpVersionIdHint}]
  -s,--ssl                    Enable SSL communication with the Controller
  --auto-launch-proxy         Sets proxy auto launch
  --enable-cli                Enable agent for CLI mode
  --enable-cli-long-running   Enable agent for long running CLI processes
  --ignore-permissions        Ignore file and directory permission issues
  --http-proxy-host=<host>    HTTP proxy host needed for communication with the Controller
  --http-proxy-port=<port>    HTTP proxy port needed for communication with the Controller
  --http-proxy-user=<user>    HTTP proxy user needed for communication with the Controller
  --http-proxy-password-file=<passwordFile> HTTP proxy password file needed for communication with the Controller.
  --tls-version=              Proxy TLS Version Argument (Default - TLSv1.2)
  --log-dir=<dir>             Sets the agent logging directory [${containingDir}/logs]
  --proxy-ctrl-dir=<dir>      Sets the proxy control directory (e.g. '/var/run/appdynamics') and disables
                              proxy auto-launch. Only set this if you intend to start the proxy manually.
  --tcp-comm-host=<host>      TCP comm host needed for communication with the proxy
  --tcp-comm-port=<port>      TCP comm port needed for communication with the proxy
  --tcp-reporting-port=<port> TCP reporting port for communication between agent and proxy
  --tcp-request-port=<port>   TCP request port for communication between agent and proxy
  --tcp-port-range=<portRange>TCP range of ports provided to proxy to pick two available ports to start communication
  --curve-enabled             Enable Curve for TCP Communication
  -u                          Uninstall agent
  -h,--help                   Show this message

Example: install.sh -s -a=accName@accKey controller1.appdynamics.com 8090 myApp myTier myNode
Note: Please use quotes for the entries where ever applicable.


EOF
}

configureZTSFlag() {
    if [ "$phpThreadSafetyStatus" = "ZTS" ]
    then
        ztsFlag="-zts"
    fi
}

if [ -z "${APPD_LOCATION}" ]; then
    APPD_LOCATION=$containingDir
    APPD_PACKAGE=0
else
    APPD_PACKAGE=1
fi

# Add possible PHP locations to PATH
pathadd /opt/zend/bin
pathadd /usr/local/bin
pathadd /usr/local/php
pathadd /usr/local/php/bin

datestamp=`date +%Y_%m_%d_%H_%M_%S 2>/dev/null`
install_log=/tmp/appd_install_${datestamp}.log
rm -f $install_log > /dev/null 2>&1
cat > $install_log <<EOF
AppDynamics PHP agent installation log
Version: ${agentVersionId}
Date: `date 2>/dev/null`

Hostname: `hostname`
Location: ${APPD_LOCATION}
System: `uname -a 2>/dev/null`
User: `id`
Environment:
################################################################################
`env | sort`
################################################################################
EOF

# defaults:
logDir="${containingDir}/logs"
proxyCtrlDir=""
phpExtDir=
phpConfDir=
ignoreFilePermissions=
cliEnabled="false"
cliLongRunningEnabled="false"
phpVersionNum=
phpVersionId=
controllerHost="localhost"
controllerPort="8080"
applicationName="MyApp"
nodeName=`hostname`
tierName=$nodeName
nodeReuse="false"
nodeReusePrefix=""
accountName=
accessKey=
sslEnabled="false"
httpProxyHost=
httpProxyPort=
httpProxyUser=
httpProxyPasswordFile=
autoLaunchProxy="1"
defaultTlsVersion="TLSv1.2"
tlsVersion=$defaultTlsVersion
tcpCommHost="127.0.0.1"
tcpCommPort=
tcpReportingPort=
tcpRequestPort=
tcpPortRange=
curveEnabled="false"
curveZapEnabled="false"


if [ -z "${APPD_AUTO_MODE}" ]; then
    action="install"
    echo "Install script for AppDynamics PHP Agent ${agentVersionId}"

    phpDir=$(getDefaultPHPPath)
    php="${phpDir}/php"
    detectPHPInfo $phpDir
    if [ -x "${php}" ] ; then
        log "Found PHP installation in ${phpDir}"
    fi
    ok=1
    optspec=":a:p:e:i:v:ss-:u-:h-:r-"
    while getopts "$optspec" optchar; do

        case "${optchar}" in
            -)
                case "${OPTARG}" in
                    help)
                        usage
                        exit 1
                        ;;
                    php-executable-path=*)
                        val=${OPTARG#*=}
                        if [ -x "${val}/php" ] ; then
                            php="${val}/php"
                            detectPHPInfo $val
                        else
                            echo "Could not find PHP binary $val" >&2
                        fi
                        ;;
                    php-extension-dir=*)
                        phpExtDir=${OPTARG#*=}
                        ;;
                    php-ini-dir=*)
                        phpConfDir=${OPTARG#*=}
                        ;;
                    php-version=*)
                        phpVersionId=${OPTARG#*=}
                        ;;
                    ignore-permissions)
                        ignoreFilePermissions="yes"
                        ;;
                    enable-cli)
                        cliEnabled="true"
                        ;;
                    enable-cli-long-running)
                        cliLongRunningEnabled="true"
                        ;;
                    node-reuse)
                        nodeReuse="true"
                        ;;
                    account-info=*)
                        val=${OPTARG#*=}
                        accountName=$(echo $val | cut -f1 -d@)
                        escapeForSedReplacement accountName "$accountName"
                        accessKey=$(echo $val | cut -f2- -d@)
                        escapeForSedReplacement accessKey "$accessKey"
                        ;;
                    ssl)
                        sslEnabled="true"
                        ;;
                    http-proxy-host=*)
                        val=${OPTARG#*=}
                        escapeForSedReplacement httpProxyHost "${val}"
                        ;;
                    http-proxy-port=*)
                        val=${OPTARG#*=}
                        escapeForSedReplacement httpProxyPort "${val}"
                        ;;
                    http-proxy-user=*)
                        val=${OPTARG#*=}
                        escapeForSedReplacement httpProxyUser "${val}"
                        ;;
                    http-proxy-password-file=*)
                        httpProxyPasswordFile=${OPTARG#*=}
                        ;;
                    log-dir=*)
                        logDir=${OPTARG#*=}
                        ;;
                    proxy-ctrl-dir=*)
                        proxyCtrlDir=${OPTARG#*=}
                        ;;
                    auto-launch-proxy=*)
                        autoLaunchProxy=${OPTARG#*=}
                        ;;
                    tls-version=*)
                        tlsVersion=${OPTARG#*=}
                        ;;
                    tcp-comm-host=*)
                        val=${OPTARG#*=}
                        escapeForSedReplacement tcpCommHost "${val}"
                        ;;
                    tcp-comm-port=*)
                        val=${OPTARG#*=}
                        escapeForSedReplacement tcpCommPort "${val}"
                        ;;
                    tcp-reporting-port=*)
                        val=${OPTARG#*=}
                        escapeForSedReplacement tcpReportingPort "${val}"
                        ;;
                    tcp-request-port=*)
                        val=${OPTARG#*=}
                        escapeForSedReplacement tcpRequestPort "${val}"
                        ;;
                    tcp-port-range=*)
                        val=${OPTARG#*=}
                        escapeForSedReplacement tcpPortRange "${val}"
                        ;;
                    curve-enabled)
                        curveEnabled="true"
                        ;;
                    curve-zap-enabled)
                        curveZapEnabled="true"
                        ;;
                    *)
                        echo "Invalid option: '--${OPTARG}'" >&2
                        ok=0
                        ;;
                esac;;

            a)
                val=${OPTARG#*=}
                accountName=$(echo $val | cut -f1 -d@)
                escapeForSedReplacement accountName "$accountName"
                accessKey=$(echo $val | cut -f2- -d@)
                escapeForSedReplacement accessKey "$accessKey"
                ;;

            p)
            val=${OPTARG#*=}
                if [ -x "${val}/php" ] ; then
                    php="${val}/php"
                    detectPHPInfo $val
                else
                    echo "Could not find PHP binary $val" >&2
                fi
                ;;
            e)
                val=${OPTARG#*=}
                phpExtDir=$val
                ;;
            i)
                val=${OPTARG#*=}
                phpConfDir=$val
                ;;
            v)
                phpVersionId=${OPTARG#*=}
                ;;
            s)
                sslEnabled="true"
                ;;
            u)
                action="uninstall"
                ;;
            r) 
                nodeReuse="true"
                ;;
            h)
                usage
                exit 1
                ;;
            *)
                if [ "$OPTERR" != 1 ] -o [ "${optspec:0:1}" = ":" ]; then
                    echo "Invalid option: '-${OPTARG}'" >&2
                    ok=0
                fi
                ;;
        esac
    done

    if [ "$ok" != 1 ]; then
        usage
        rm -f ${install_log}
        exit 1
    fi

    shift `expr $OPTIND - 1`

    if [ "${action}" = "install" ]; then
        if [ "$#" -lt 5 ] ; then
            echo "Missing required arguments" >&2
            usage
            rm -f ${install_log}
            exit 1
        fi

        if [ "$#" -gt 5 ] ; then
            shift 5
            echo "Extra arguments: $*" >&2
            usage
            rm -f ${install_log}
            exit 1
        fi

        
        if [ "$tlsVersion" != "TLSv1.2" ] && [ "$tlsVersion" != "TLSv1.3" ]; then
            echo "TLS version '$tlsVersion' is not supported. Supported TLS versions are: TLSv1.2, TLSv1.3 Switching to default (TLSv1.2)"
            tlsVersion=$defaultTlsVersion
        fi

        escapeForSedReplacement controllerHost "$1"
        escapeForSedReplacement controllerPort "$2"
        escapeForSedReplacement applicationName "$3"
        escapeForSedReplacement tierName "$4"
        escapeForSedReplacement nodeName "$5"
    fi
else
    action=$APPD_AUTO_MODE
    if [ -n "${APPD_PHP_PATH}" ]; then
        if [ -x "${APPD_PHP_PATH}/php" ] ; then
            php="${APPD_PHP_PATH}/php"
            detectPHPInfo $APPD_PHP_PATH
            log "Found PHP installation in ${APPD_PHP_PATH}"
        else
            fatal_error "Could not find PHP binary in specified location: ${APPD_PHP_PATH}"
        fi
    else
        phpDir=$(getDefaultPHPPath)
        # Do the usual checks for install mode. For uninstall, we shouldn't fail
        # hard if the PHP binary is not found.
        if [ -d "${phpDir}" ]; then
          php="${phpDir}/php"
          detectPHPInfo $phpDir
          log "Found PHP installation in ${phpDir}"
        fi
    fi


    phpExtDir="${APPD_PHP_EXTENSION_DIR}"
    phpConfDir="${APPD_PHP_CONFIGURATION_DIR}"
    phpVersionId="${APPD_PHP_VERSION}"

    [ -n "${APPD_CONF_CONTROLLER_HOST}" ] && escapeForSedReplacement controllerHost "${APPD_CONF_CONTROLLER_HOST}"
    [ -n "${APPD_CONF_CONTROLLER_PORT}" ] && escapeForSedReplacement controllerPort "${APPD_CONF_CONTROLLER_PORT}"
    [ -n "${APPD_CONF_APP}" ] && escapeForSedReplacement applicationName "${APPD_CONF_APP}"
    [ -n "${APPD_CONF_TIER}" ] && escapeForSedReplacement tierName "${APPD_CONF_TIER}"
    [ -n "${APPD_CONF_NODE}" ] && escapeForSedReplacement nodeName "${APPD_CONF_NODE}"
    if [ -n "${APPD_CONF_NODE_REUSE}" ]; then
        case "${APPD_CONF_NODE_REUSE}" in
            [tT][rR][uU][eE]) nodeReuse=true ;;
            *) ;;
        esac
    fi
    [ -n "${APPD_CONF_ACCOUNT_NAME}" ] && escapeForSedReplacement accountName "${APPD_CONF_ACCOUNT_NAME}"
    [ -n "${APPD_CONF_ACCESS_KEY}" ] && escapeForSedReplacement accessKey "${APPD_CONF_ACCESS_KEY}"
    if [ -n "${APPD_CONF_SSL_ENABLED}" ]; then
        case "${APPD_CONF_SSL_ENABLED}" in
            [tT][rR][uU][eE]) sslEnabled=true ;;
            *) ;;
        esac
    fi
    [ -n "${APPD_CONF_HTTP_PROXY_HOST}" ] && escapeForSedReplacement httpProxyHost "${APPD_CONF_HTTP_PROXY_HOST}"
    [ -n "${APPD_CONF_HTTP_PROXY_PORT}" ] && escapeForSedReplacement httpProxyPort "${APPD_CONF_HTTP_PROXY_PORT}"
    [ -n "${APPD_CONF_HTTP_PROXY_USER}" ] && escapeForSedReplacement httpProxyUser "${APPD_CONF_HTTP_PROXY_USER}"
    [ -n "${APPD_CONF_HTTP_PROXY_PASSWORD_FILE}" ] && httpProxyPasswordFile="${APPD_CONF_HTTP_PROXY_PASSWORD_FILE}"
    [ -n "${APPD_CONF_AUTO_LAUNCH_PROXY}" ] && escapeForSedReplacement autoLaunchProxy "${APPD_CONF_AUTO_LAUNCH_PROXY}"
    [ -n "${APPD_CONF_TLS_VERSION}" ] && escapeForSedReplacement tlsVersion "${APPD_CONF_TLS_VERSION}"
    if [ -n "${APPD_CONF_CLI_ENABLED}" ]; then
        case "${APPD_CONF_CLI_ENABLED}" in
            [tT][rR][uU][eE]) cliEnabled=true ;;
            *) ;;
        esac
    fi
    if [ -n "${APPD_CONF_CLI_LONG_RUNNING_ENABLED}" ]; then
        case "${APPD_CONF_CLI_LONG_RUNNING_ENABLED}" in
            [tT][rR][uU][eE]) cliLongRunningEnabled=true ;;
            *) ;;
        esac
    fi
    [ -n "${APPD_CONF_LOG_DIR}" ] && logDir="${APPD_CONF_LOG_DIR}"
    [ -n "${APPD_CONF_PROXY_CTRL_DIR}" ] && proxyCtrlDir="${APPD_CONF_PROXY_CTRL_DIR}"
    [ -n "${APPD_CONF_TCP_COMM_HOST}" ] && escapeForSedReplacement tcpCommHost "${APPD_CONF_TCP_COMM_HOST}"
    [ -n "${APPD_CONF_TCP_COMM_PORT}" ] && escapeForSedReplacement tcpCommPort "${APPD_CONF_TCP_COMM_PORT}"
    [ -n "${APPD_CONF_TCP_REPORTING_PORT}" ] && escapeForSedReplacement tcpReportingPort "${APPD_CONF_TCP_REPORTING_PORT}"
    [ -n "${APPD_CONF_TCP_REQUEST_PORT}" ] && escapeForSedReplacement tcpRequestPort "${APPD_CONF_TCP_REQUEST_PORT}"
    [ -n "${APPD_CONF_TCP_PORT_RANGE}" ] && escapeForSedReplacement tcpPortRange "${APPD_CONF_TCP_PORT_RANGE}"
    if [ -n "${APPD_CONF_CURVE_ENABLED}" ]; then
        case "${APPD_CONF_CURVE_ENABLED}" in
            [tT][rR][uU][eE]) curveEnabled=true ;;
            *) ;;
        esac
    fi
    if [ -n "${APPD_CONF_CURVE_ZAP_ENABLED}" ]; then
        case "${APPD_CONF_CURVE_ZAP_ENABLED}" in
            [tT][rR][uU][eE]) curveZapEnabled=true ;;
            *) ;;
        esac
    fi
fi

if [ -n "${phpVersionId}" ] ; then
    case "${phpVersionId}" in
        7.4|7.4.*)
            phpVersionNum=70400
            phpVersionId=7.4
            ;;
        8.0|8.0.*)
            phpVersionNum=80000
            phpVersionId=8.0
            ;;
        8.1|8.1.*)
            phpVersionNum=80100
            phpVersionId=8.1
            ;;
        8.2|8.2.*)
            phpVersionNum=80200
            phpVersionId=8.2
            ;;
        *)
            log_error "PHP Version ${phpVersionId} is not supported."
            fatal_error "PHP Version must be one of 7.4, 8.0, 8.1 or 8.2"
            ;;
    esac
fi

if [ ${nodeReuse} = "true"  ]; then
    nodeReusePrefix=${nodeName}
fi

resolvePHPInfo

checkPHPProperty "PHP extensions directory" "${phpExtDir}"
checkPHPProperty "PHP version" "${phpVersionId}"
checkPHPProperty "PHP version" "${phpVersionNum}"
checkPHPProperty "PHP thread safety" "${phpThreadSafetyStatus}"

configureZTSFlag

if [ -x "${php}" ] ; then
  phpVersionInfo=`${php} -v 2>/dev/null`
  log "
  Detected PHP Version:
  $phpVersionInfo"
else
  log "PHP CLI not found."
fi

install_agent() {

################################################################################
# Validate
################################################################################

log
log "PHP version id:            $phpVersionId"
log "PHP extensions directory:  $phpExtDir"
log "PHP ini directory:         $phpConfDir"
log "PHP thread safety:         $phpThreadSafetyStatus"
log "Controller Host:           $controllerHost"
log "Controller Port:           $controllerPort"
log "Application Name:          $applicationName"
log "Tier Name:                 $tierName"
log "Node Name:                 $nodeName"
log "Node Reuse:                $nodeReuse"
log "Node Reuse Prefix:         $nodeReusePrefix"
log "Account Name:              $accountName"
log "Access Key:                $accessKey"
log "SSL Enabled:               $sslEnabled"
log "HTTP Proxy Host:           $httpProxyHost"
log "HTTP Proxy Port:           $httpProxyPort"
log "HTTP Proxy User:           $httpProxyUser"
log "HTTP Proxy Password File:  $httpProxyPasswordFile"
log "Auto Launch Proxy:         $autoLaunchProxy"
log "TLS Version:               $tlsVersion"
log "TCP Comm Host:             $tcpCommHost"
log "TCP Comm Port:             $tcpCommPort"
log "TCP Reporting Port:        $tcpReportingPort"
log "TCP Request Port:          $tcpRequestPort"
log "TCP Port Range:            $tcpPortRange"
log "Curve Enabled:             $curveEnabled"              
log "Curve Zap Enabled:         $curveZapEnabled"              
log

#__result=`$php -i 2> /dev/null | grep "Thread Safety => enabled"`
#if [ -n "$__result" ] ; then
#    fatal_error "Please disable ZTS before installing."
#fi

PATH="/sbin:/usr/sbin:$PATH"
export PATH
getenforce=`which getenforce 2>/dev/null`
if [ -f "${getenforce}" ]; then
    selStatus=`$getenforce`
    if [ "$selStatus" = "Enforcing" ] ; then
        log "Warning: You may encounter issues with SELinux and AppDynamics. Please refer to the AppDynamics documentation at https://docs.appdynamics.com for information on creating an SELinux policy for AppDynamics support."
    fi
fi

if [ $phpVersionNum -lt 70400 -o $phpVersionNum -gt 80299 ]; then
    fatal_error "Only PHP versions 7.4, and 8.0-8.2 are currently supported"

fi

if [ -n "$phpExtDir" -a ! -d "$phpExtDir" ]; then
    if ! mkdir -p "${phpExtDir}" 2>/dev/null; then
        fatal_error "PHP extensions directory '$phpExtDir' could not be created"
    fi
fi

if [ -n "$phpExtDir" -a ! -w "$phpExtDir" ]; then
    fatal_error "PHP extensions directory '$phpExtDir' not writable.
Try running this script as root."
fi

if [ -n "$phpConfDir" -a ! -d "$phpConfDir" ]; then
    if ! mkdir -p "${phpConfDir}" 2>/dev/null; then
        fatal_error "PHP extensions config directory '$phpConfDir' could not be created"
    fi
fi

if [ -n "$phpConfDir" -a ! -w "$phpConfDir" ]; then
    fatal_error "PHP extensions config directory '$phpConfDir' not writable
Try running this script as root."
fi

# If httpProxyHost xor httpProxyPort are set, then complain.
if [ -n "$httpProxyHost" -a -z "$httpProxyPort" ]; then
    fatal_error "HTTP proxy host is '${httpProxyHost}', but http proxy port is not set."
elif [ -n "$httpProxyPort" -a -z "$httpProxyHost" ] ; then
    fatal_error "HTTP proxy port is '${httpProxyPort}', but http proxy host is not set."
fi

# If httpProxyUser or httpProxyPasswordFile are set, everything needs to be set.
if [ -n "$httpProxyUser" -o -n "$httpProxyPasswordFile" ]; then
    if [ -z "$httpProxyHost" -o -z "$httpProxyPort" -o -z "$httpProxyUser" -o -z "$httpProxyPasswordFile" ]; then
        fatal_error "If the HTTP proxy user (value: \"$httpProxyUser\") or HTTP password file
        (value: \"$httpProxyPasswordFile\") are set, then all proxy parameters must be set. Try setting all values."
    fi
fi

if [ ! -r "$containingDir/php/modules/appdynamics_agent_php${ztsFlag}_$phpVersionId.so" ] ; then
    fatal_error "Agent installation does not contain PHP extension for PHP ${phpVersionId}"
fi

## Installed files locations
log4cxxFile="${containingDir}/php/conf/appdynamics_agent_log4cxx.xml"
runProxyScript="${containingDir}/proxy/runProxy"
controllerInfo="${containingDir}/proxy/conf/controller-info.xml"
if [ -n "$phpConfDir" ]; then
    targetAgentIniFile="$(realPath $phpConfDir)/appdynamics_agent.ini"
else
    targetAgentIniFile=`mktemp`
fi
targetAgentSharedLib="$(realPath $phpExtDir)/appdynamics_agent.so"

if [ $curveEnabled = true ]; then
    # Public Key Files
    publicKeyDirectory="${containingDir}/certs/public"
    agentPublicKeyFile="${publicKeyDirectory}/${nodeName}.key"
    proxyPublicKeyFile="${publicKeyDirectory}/proxy.key"

    # Secret Key Files
    secretKeyDirectory="${containingDir}/certs/secret"
    agentSecretKeyFile="${secretKeyDirectory}/${nodeName}.key_secret"
    proxySecretKeyFile="${secretKeyDirectory}/proxy.key_secret"

    # Check if Public Key Directory exists
    if [ ! -e "${publicKeyDirectory}" ]; then
        echo "Public key directory ${publicKeyDirectory} does not exist; creating."
        mkdir -p "${publicKeyDirectory}" || echo "Failed to create public key directory ${publicKeyDirectory}"
        chmod o+wx "${publicKeyDirectory}" || echo "Failed to set permissions on public key directory ${publicKeyDirectory}"
    else
        echo "Public key directory ${publicKeyDirectory} already exists."
    fi

    # Check if Secret Key Directory exists
    if [ ! -e "${secretKeyDirectory}" ]; then
        echo "Secret key directory ${secretKeyDirectory} does not exist; creating."
        mkdir -p "${secretKeyDirectory}" || echo "Failed to create secret key directory ${secretKeyDirectory}"
        chmod o+wx "${secretKeyDirectory}" || echo "Failed to set permissions on secret key directory ${secretKeyDirectory}"
    else
        echo "Secret key directory ${secretKeyDirectory} already exists."
    fi

    # Check and create Agent Public Key File if it doesn't exist
    if [ ! -e "$agentPublicKeyFile" ]; then
        echo "Creating agent public key file: ${agentPublicKeyFile}"
        touch "$agentPublicKeyFile" || echo "Failed to create agent public key file: ${agentPublicKeyFile}"
    else
        echo "Agent public key file ${agentPublicKeyFile} already exists."
    fi

    # Check and create Agent Secret Key File if it doesn't exist
    if [ ! -e "$agentSecretKeyFile" ]; then
        echo "Creating agent secret key file: ${agentSecretKeyFile}"
        touch "$agentSecretKeyFile" || echo "Failed to create agent secret key file: ${agentSecretKeyFile}"
    else
        echo "Agent secret key file ${agentSecretKeyFile} already exists."
    fi
fi

if [ -z "${APPD_AUTO_MODE}" ]; then
    rootDirCheck=
    checkPathIsAccessible rootDirCheck "${containingDir}"
    if [ -n "${rootDirCheck}" ] ; then
        log_error "PHP agent directory '${containingDir}' is not readable by all users"
        if [ "${ignoreFilePermissions}" != "yes" ] ; then
            fatal_error "Change the permissions of '${rootDirCheck}' or specify --ignore-permissions"
        fi
    fi

    if [ ! -e "${logDir}" ]; then
        log "Log directory ${logDir} does not exist; creating."
        mkdir -p "${logDir}" || fatal_error "Failed to create log directory ${logDir}"
        chmod o+wx "${logDir}" || fatal_error "Failed to set permissions on log directory ${logDir}"
    else
        [ -d "${logDir}" ] || fatal_error "Log directory ${logDir} is not a directory"
    fi

    if [ -n "${proxyCtrlDir}" ]; then
        if [ ! -e "${proxyCtrlDir}" ]; then
            log "Proxy control directory ${proxyCtrlDir} does not exist; creating."
            mkdir -p "${proxyCtrlDir}" || fatal_error "Failed to create proxy control directory ${proxyCtrlDir}"
            chmod o+wx "${proxyCtrlDir}" || fatal_error "Failed to set permissions on proxy control directory ${proxyCtrlDir}"
        else
            [ -d "${proxyCtrlDir}" ] || fatal_error "Proxy control directory ${proxyCtrlDir} is not a directory"
        fi
    fi

    logsDirCheck=$(find "${logDir}" -maxdepth 0 -perm -003 2>/dev/null)
    if [ -z "${logsDirCheck}" ] ; then
        log_error "PHP agent logs directory '${logDir}' is not writable by all users"
        if [ "${ignoreFilePermissions}" != "yes" ] ; then
            fatal_error "Change the permissions of '${logDir}' or specify --ignore-permissions"
        fi
    fi
else
    if [ -z "${phpConfDir}" ]; then
        fatal_error "Unable to determine PHP extensions config directory.
Please re-run installer manually."
    fi
fi

if [ "${phpSuhosinPatchStatus}" = "patched" ] ; then
    if [ "${cliLongRunningEnabled}" = "true" ] ; then
        fatal_error "Long running CLI processes are not supported on PHP versions with the Suhosin patch!"
    fi
elif [ "${phpSuhosinPatchStatus}" != "notpatched" ] ; then
    warn "Unable to detect Suhosin patch status!"
fi

if [ "${cliEnabled}" = "true" ] ; then
    if [ "${phpSuhosinPatchStatus}" = "notpatched" -a \
         "${cliLongRunningEnabled}" != "true" ] ; then
        log "Automatically enabling support for long running CLI processes, since Suhosin patch is not present."
        cliLongRunningEnabled="true"
    fi

    if [ "${cliLongRunningEnabled}" != "true" ] ; then
        warn "Long running CLI process support is not enabled, agent may leak memory in long running CLI processes!"
    fi
fi



# write log4cxx file
escapeForSedReplacement agentLogFile "${logDir}/agent.log"
log4cxxTemplate="${log4cxxFile}.template"
log4cxxTemplateOwner=$(stat "${statFormatOpt}%u" "${log4cxxTemplate}")
log4cxxTemplateGroup=$(stat "${statFormatOpt}%g" "${log4cxxTemplate}")
log "Writing '${log4cxxFile}'"
cat "${log4cxxTemplate}" | \
    sed -e "s/__agent_log_file__/${agentLogFile}/g"    \
         > "${log4cxxFile}"
if [ $? -ne 0 ] ; then
    fatal_error "Unable to write '${log4cxxFile}'"
fi

chown "${log4cxxTemplateOwner}" "${log4cxxFile}"
chgrp "${log4cxxTemplateGroup}" "${log4cxxFile}"
chmod a+r "${log4cxxFile}"

# write agent ini file, if possible
if [ -n "$phpConfDir" ]; then
    log "Writing '$targetAgentIniFile'"
fi
srcAgentIniFile=$(realPath "$containingDir/php/conf/appdynamics_agent.ini")
cat "$srcAgentIniFile" | grep -v "^;.*" > "$targetAgentIniFile"
if [ $? -ne 0 ] ; then
    fatal_error "Unable to update '$srcAgentIniFile'"
fi

agentTagsIniFilePath=$(realPath "$containingDir/appdynamics_tags.ini")
echo "agent.agent_tags_ini_file_path = ${agentTagsIniFilePath}" >> "$targetAgentIniFile"
if [ $? -ne 0 ] ; then
    fatal_error "Unable to update '$srcAgentIniFile'"
fi

echo "agent.log4cxx_config = ${log4cxxFile}" >> "$targetAgentIniFile"
if [ $? -ne 0 ] ; then
    fatal_error "Unable to update '$srcAgentIniFile'"
fi

echo "agent.php_agent_root = ${containingDir}" >> "$targetAgentIniFile"
if [ $? -ne 0 ] ; then
    fatal_error "Unable to update '$srcAgentIniFile'"
fi

if [ "${cliEnabled}" = "true" -o "${cliLongRunningEnabled}" = "true" ]; then
    echo "agent.cli_enabled = On" >> "$targetAgentIniFile"
    if [ $? -ne 0 ] ; then
        fatal_error "Unable to update '$srcAgentIniFile'"
    fi

    if [ "${cliLongRunningEnabled}" = "true" ] ; then
        longRunningINIValue="On"
    else
        longRunningINIValue="Off"
    fi

    echo "agent.cli_long_running = ${longRunningINIValue}" >> "$targetAgentIniFile"
    if [ $? -ne 0 ] ; then
        fatal_error "Unable to update '$srcAgentIniFile'"
    fi

fi

echo "agent.controller.hostName = ${controllerHost}" >> "$targetAgentIniFile"
if [ $? -ne 0 ] ; then
    fatal_error "Unable to update '$srcAgentIniFile'"
fi

echo "agent.controller.port = ${controllerPort}" >> "$targetAgentIniFile"
if [ $? -ne 0 ] ; then
    fatal_error "Unable to update '$srcAgentIniFile'"
fi

echo "agent.applicationName = ${applicationName}" >> "$targetAgentIniFile"
if [ $? -ne 0 ] ; then
    fatal_error "Unable to update '$srcAgentIniFile'"
fi

echo "agent.tierName = ${tierName}" >> "$targetAgentIniFile"
if [ $? -ne 0 ] ; then
    fatal_error "Unable to update '$srcAgentIniFile'"
fi

echo "agent.nodeName = ${nodeName}" >> "$targetAgentIniFile"
if [ $? -ne 0 ] ; then
    fatal_error "Unable to update '$srcAgentIniFile'"
fi

if [ ${nodeReuse} = "true"  ]; then
    echo "agent.nodeReuse = 1" >> "$targetAgentIniFile"
    echo "agent.nodeReusePrefix = ${nodeReusePrefix}" >> "$targetAgentIniFile"
    if [ $? -ne 0 ] ; then
        fatal_error "Unable to update '$srcAgentIniFile'"
    fi
fi


if [ -n "${httpProxyHost}" -a -n "${httpProxyPort}" ]; then
    echo "agent.http.proxyHost = ${httpProxyHost}" >> "$targetAgentIniFile"
    if [ $? -ne 0 ] ; then
        fatal_error "Unable to update '$srcAgentIniFile'"
    fi
    echo "agent.http.proxyPort = ${httpProxyPort}" >> "$targetAgentIniFile"
    if [ $? -ne 0 ] ; then
        fatal_error "Unable to update '$srcAgentIniFile'"
    fi
    echo "agent.http.proxyUser = ${httpProxyUser}" >> "$targetAgentIniFile"
    if [ $? -ne 0 ] ; then
        fatal_error "Unable to update '$srcAgentIniFile'"
    fi
    echo "agent.http.proxyPasswordFile = ${httpProxyPasswordFile}" >> "$targetAgentIniFile"
    if [ $? -ne 0 ] ; then
        fatal_error "Unable to update '$srcAgentIniFile'"
    fi
fi

if [ ${sslEnabled} = "true"  ]; then
    echo "agent.controller.ssl.enabled = 1" >> "$targetAgentIniFile"
    if [ $? -ne 0 ] ; then
        fatal_error "Unable to update '$srcAgentIniFile'"
    fi
fi

if [ ${accountName} ] ; then
    echo "agent.accountName = ${accountName}" >> "$targetAgentIniFile"
    if [ $? -ne 0 ] ; then
        fatal_error "Unable to update '$srcAgentIniFile'"
    fi
fi

if [ ${accessKey} ] ; then
    echo "agent.accountAccessKey = ${accessKey}" >> "$targetAgentIniFile"
    if [ $? -ne 0 ] ; then
        fatal_error "Unable to update '$srcAgentIniFile'"
    fi
fi

if [ -n "${proxyCtrlDir}" ]; then
    echo "agent.proxy_ctrl_dir = ${proxyCtrlDir}" >> "$targetAgentIniFile"
    echo "agent.auto_launch_proxy = 0" >> "$targetAgentIniFile"
fi

agent_os_name=$(grep PRETTY_NAME /etc/os-release | awk -F= '{gsub("\"", "", $2); print $2}')
if [ -n "${agent_os_name}" ]; then
    echo agent.metadata.agent_os_name = "\"${agent_os_name}\"" >> "$targetAgentIniFile"
    if [ $? -ne 0 ] ; then
        fatal_error "Unable to update '$srcAgentIniFile'"
    fi
fi

agent_config_path="$(realPath $phpConfDir)/appdynamics_agent.ini"
if [ -n "${agent_config_path}" ]; then
    echo agent.metadata.agent_config_path = "\"${agent_config_path}\"" >> "$targetAgentIniFile"
    if [ $? -ne 0 ] ; then
        fatal_error "Unable to update '$srcAgentIniFile'"
    fi
fi

agent_installation_path=${containingDir}
if [ -n "${agent_installation_path}" ]; then
    echo agent.metadata.agent_installation_path = "\"${agent_installation_path}\"" >> "$targetAgentIniFile"
    if [ $? -ne 0 ] ; then
        fatal_error "Unable to update '$srcAgentIniFile'"
    fi
fi

agent_php_version_id=${phpVersionId}
if [ -n "${agent_php_version_id}" ]; then
    echo agent.metadata.agent_php_version_id = "\"${agent_php_version_id}\"" >> "$targetAgentIniFile"
    if [ $? -ne 0 ] ; then
        fatal_error "Unable to update '$srcAgentIniFile'"
    fi
fi

if [ -n "${autoLaunchProxy}" ]; then
    echo "agent.auto_launch_proxy = ${autoLaunchProxy}" >> "$targetAgentIniFile"
fi

if [ -n "${tcpCommHost}" -a -n "${tcpCommPort}" ]; then
    echo "agent.tcp.commHost = ${tcpCommHost}" >> "$targetAgentIniFile"
    if [ $? -ne 0 ] ; then
        fatal_error "Unable to update '$srcAgentIniFile'"
    fi
    echo "agent.tcp.commPort = ${tcpCommPort}" >> "$targetAgentIniFile"
    if [ $? -ne 0 ] ; then
        fatal_error "Unable to update '$srcAgentIniFile'"
    fi
    echo "agent.tcp.reportingPort = ${tcpReportingPort}" >> "$targetAgentIniFile"
    if [ $? -ne 0 ] ; then
        fatal_error "Unable to update '$srcAgentIniFile'"
    fi
    echo "agent.tcp.requestPort = ${tcpRequestPort}" >> "$targetAgentIniFile"
    if [ $? -ne 0 ] ; then
        fatal_error "Unable to update '$srcAgentIniFile'"
    fi
    echo "agent.tcp.portRange = ${tcpPortRange}" >> "$targetAgentIniFile"
    if [ $? -ne 0 ] ; then
        fatal_error "Unable to update '$srcAgentIniFile'"
    fi
    if [ $curveEnabled = "true" ]; then
        echo "agent.curve.enabled = 1" >> "$targetAgentIniFile"
        if [ $? -ne 0 ] ; then
            fatal_error "Unable to update '$srcAgentIniFile'"
        fi
        if [ $curveZapEnabled = "true" ]; then
            echo "agent.curve.zap_enabled = 1" >> "$targetAgentIniFile"
            if [ $? -ne 0 ] ; then
                fatal_error "Unable to update '$srcAgentIniFile'"
            fi
        fi
        echo "agent.curve.public_key_dir = ${publicKeyDirectory}" >> "$targetAgentIniFile"
        if [ $? -ne 0 ] ; then
            fatal_error "Unable to update '$srcAgentIniFile'"
        fi
        echo "agent.curve.secret_key_dir = ${secretKeyDirectory}" >> "$targetAgentIniFile"
        if [ $? -ne 0 ] ; then
            fatal_error "Unable to update '$srcAgentIniFile'"
        fi
        echo "agent.curve.agent_public_key_file = ${agentPublicKeyFile}" >> "$targetAgentIniFile"
        if [ $? -ne 0 ] ; then
            fatal_error "Unable to update '$srcAgentIniFile'"
        fi
        echo "agent.curve.agent_secret_key_file = ${agentSecretKeyFile}" >> "$targetAgentIniFile"
        if [ $? -ne 0 ] ; then
            fatal_error "Unable to update '$srcAgentIniFile'"
        fi
        echo "agent.curve.proxy_public_key_file = ${proxyPublicKeyFile}" >> "$targetAgentIniFile"
        if [ $? -ne 0 ] ; then
            fatal_error "Unable to update '$srcAgentIniFile'"
        fi
        echo "agent.curve.proxy_secret_key_file = ${proxySecretKeyFile}" >> "$targetAgentIniFile"
        if [ $? -ne 0 ] ; then
            fatal_error "Unable to update '$srcAgentIniFile'"
        fi
    fi
fi

chmod a+r "${targetAgentIniFile}"

if [ -z "${phpConfDir}" ]; then
    ## If we got here, then we are not doing an auto-install
    echo
    echo "*** Unable to determine PHP config file fragments directory      ***"
    echo "*** Please copy the INI fragment below to your main php.ini file ***"
    echo "--------------------------------------------------------------------"
    cat $targetAgentIniFile
    echo "--------------------------------------------------------------------"
    echo
    rm $targetAgentIniFile
fi

# Write controller-info.xml
log "Writing '${controllerInfo}'"

if [ -z "${phpConfDir}" ]; then
    INI_LOCATION_MSG="if it has not already been written into your main php.ini file."
else
    INI_LOCATION_MSG="which the installer has written into ${targetAgentIniFile}"
fi

cat > "${controllerInfo}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<controller-info>
<!-- controller-info.xml is no longer used by the AppDynamics PHP agent.
     To specify your controller information, please use the INI fragment below,
     ${INI_LOCATION_MSG}

EOF
cat $targetAgentIniFile >> "${controllerInfo}"

cat >> "${controllerInfo}" <<EOF

-->
</controller-info>
EOF

# Change ownership controller info xml to match the ownership
# of the file in the tarball.  This way the user
# that extracted the tarball can also delete the generated file
# even if this script was run as root.
chown "${controllerInfoTemplateOwner}" "${controllerInfo}"
chgrp "${controllerInfoTemplateGroup}" "${controllerInfo}"
chmod a+r "${controllerInfo}"

# write Agent shared library
srcAgentSharedLib=$(realPath "$containingDir/php/modules/appdynamics_agent_php${ztsFlag}_$phpVersionId.so")
log "rm -f \"$targetAgentSharedLib\""
rm -f "$targetAgentSharedLib"
log "ln -s \"$srcAgentSharedLib\" \"$targetAgentSharedLib\""
ln -s "$srcAgentSharedLib" "$targetAgentSharedLib"
if [ $? -ne 0 ] ; then
    fatal_error "Agent: Unable to link '${targetAgentSharedLib}'"
fi

chown -R root:root "$containingDir/php/modules"
chmod -R go-w "$containingDir/php/modules"
chmod -R u+w "$containingDir/php/modules"

# write shared library required by the Agent
targetSharedLibPath="$(realPath $phpExtDir)"
for srcSharedLib in `realPath "$containingDir/php/third-party-lib/*.so*"`
do
    srcSharedLibFile=`basename $srcSharedLib`
    targetSharedLib=$targetSharedLibPath/$srcSharedLibFile
    log "rm -f \"$targetSharedLib\""
    rm -f "$targetSharedLib"
    log "ln -s \"$srcSharedLib\" \"$targetSharedLib\""
    ln -s "$srcSharedLib" "$targetSharedLib"
    if [ $? -ne 0 ] ; then
        fatal_error "Dynamic Library: Unable to link '${targetSharedLib}'"
    fi
done

chown -R root:root "$containingDir/php/third-party-lib"
chmod -R go-w "$containingDir/php/third-party-lib"
chmod -R u+w "$containingDir/php/third-party-lib"

# write runProxy script
runProxyTemplate="${runProxyScript}.template"
runProxyTemplateOwner=$(stat "${statFormatOpt}%u" "${runProxyTemplate}")
runProxyTemplateGroup=$(stat "${statFormatOpt}%g" "${runProxyTemplate}")
log "Writing '${runProxyScript}'"
cat "${runProxyTemplate}" | \
    sed -e "s/^httpProxyHost=\$/httpProxyHost=\"${httpProxyHost}\"/" \
        -e "s/^httpProxyPort=\$/httpProxyPort=${httpProxyPort}/" \
        -e "s/^httpProxyUser=\$/httpProxyUser=${httpProxyUser}/" \
        -e "s|^httpProxyPasswordFile=\$|httpProxyPasswordFile=${httpProxyPasswordFile}|" \
        -e "/set -- \"\$@\" -Dlog4j.ignoreTCL=true/a\\set -- \"\$@\" -Dappdynamics.agent.ssl.protocol=${tlsVersion}" \
        > "${runProxyScript}"
chown "${runProxyTemplateOwner}" "${runProxyScript}"
chgrp "${runProxyTemplateGroup}" "${runProxyScript}"
chmod a+rx "${runProxyScript}"

return 0
}

uninstall_agent() {
if [ -n "${phpExtDir}" ] ; then
    log "Removing agent extension from ${phpExtDir}"
    rm -f "$(realPath $phpExtDir)/appdynamics_agent.so"
fi

# Save config files
configFiles=
if [ -f "${containingDir}/php/conf/appdynamics_agent_log4cxx.xml" ]; then
    configFiles="${configFiles} ${containingDir}/php/conf/appdynamics_agent_log4cxx.xml"
fi
if [ -f "${containingDir}/proxy/conf/controller-info.xml" ]; then
    configFiles="${configFiles} ${containingDir}/proxy/conf/controller-info.xml"
fi
if [ -n "${phpConfDir}" ]; then
    agentIniFile="$(realPath $phpConfDir)/appdynamics_agent.ini"
    if [ -f "${agentIniFile}" ]; then
        configFiles="${configFiles} ${agentIniFile}"
    fi
fi

if [ -f "${containingDir}/proxy/runProxy" ]; then
    configFiles="${configFiles} ${containingDir}/proxy/runProxy"
fi

if [ -n "${configFiles}" ]; then
    configTar="$(mktemp -u -t appd_configs.XXXXX).tar"
    cp $configFiles /tmp
    (cd /tmp
     savedFiles=
     for file in $configFiles; do
         savedConfigFiles="${savedConfigFiles} ${file##*/}"
     done
     tar cf $configTar $savedConfigFiles >/dev/null 2>&1
     rm -f $savedConfigFiles
    )

    rm -f $configFiles
    cat <<EOF
AppDynamics PHP agent uninstalled. The existing configurations files have been
saved in:

    ${configTar}
EOF
fi

return 0
}

[ "${action}" = "install" ] && install_agent
[ "${action}" = "uninstall" ] && uninstall_agent

rm -f ${install_log}