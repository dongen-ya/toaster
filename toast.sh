#!/bin/bash

echo_() {
    echo "$1"
    echo "$1" >> /tmp/toast.log
}

success() {
    echo -e "$(tput setaf 2)$1$(tput sgr0)"
    echo "$1" >> /tmp/toast.log
}

inform() {
    echo -e "$(tput setaf 6)$1$(tput sgr0)"
    echo "$1" >> /tmp/toast.log
}

warning() {
    echo -e "$(tput setaf 1)$1$(tput sgr0)"
    echo "$1" >> /tmp/toast.log
}

################################################################################

# root
if [ "${HOME}" == "/root" ]; then
    warning "Not supported ROOT."
    exit 1
fi

# linux
OS_NAME=`uname`
if [ "${OS_NAME}" == "Linux" ]; then
    OS_FULL=`uname -a`
    if [ `echo ${OS_FULL} | grep -c "amzn1"` -gt 0 ]; then
        OS_TYPE="amzn1"
    elif [ `echo ${OS_FULL} | grep -c "el6"` -gt 0 ]; then
        OS_TYPE="el6"
    elif [ `echo ${OS_FULL} | grep -c "el7"` -gt 0 ]; then
        OS_TYPE="el7"
    elif [ `echo ${OS_FULL} | grep -c "generic"` -gt 0 ]; then
        OS_TYPE="generic"
    fi
else
    if [ "${OS_NAME}" == "Darwin" ]; then
        OS_TYPE="${OS_NAME}"
    fi
fi

if [ "${OS_TYPE}" == "" ]; then
    echo_ "`uname -a`"
    warning "Not supported OS - [${OS_NAME}][${OS_TYPE}]"
    exit 1
fi

# sudo
SUDO="sudo"

################################################################################

SHELL_DIR=$(dirname $0)

TOAST_URL=
REPO_PATH=
ORG=
PHASE=
FLEET=
UUID=
NAME=
HOST=
PORT=
USER=
TOKEN=
SNO=

CONFIG="${HOME}/.toast"
if [ -f "${CONFIG}" ]; then
    source ${CONFIG}
fi

if [ "${ORG}" != "" ]; then
    TOAST_URL="http://${ORG}.toast.sh"
fi

UUID=`curl -s http://instance-data/latest/meta-data/instance-id`
USER=`whoami`

################################################################################

CMD=$1

PARAM1=$2
PARAM2=$3
PARAM3=$4
PARAM4=$5
PARAM5=$6
PARAM6=$7

HAS_WAR="FALSE"
HAS_JAR="FALSE"

DATA_DIR="/data"
APPS_DIR="${DATA_DIR}/apps"
LOGS_DIR="${DATA_DIR}/logs"
SITE_DIR="${DATA_DIR}/site"
TEMP_DIR="/tmp"

HTTPD_VERSION="22"

TOMCAT_DIR="${APPS_DIR}/tomcat8"
WEBAPP_DIR="${TOMCAT_DIR}/webapps"

################################################################################

toast() {
    case ${CMD} in
        a|auto)
            auto
            ;;
        u|update)
            update
            ;;
        p|prepare)
            prepare
            ;;
        c|config)
            config
            ;;
        i|init|install)
            init
            ;;
        v|version)
            version
            ;;
        o|vhost)
            vhost
            ;;
        d|deploy)
            deploy
            ;;
        h|health)
            health
            ;;
        s|ssh)
            connect
            ;;
        r|reset)
            reset
            ;;
        l|log)
            log
            ;;
        *)
            usage
    esac
}

usage() {
    echo_toast

    echo_ " Usage: toast {auto|update|config|init|version|deploy}"
    echo_bar
    echo_
    echo_ " Usage: toast auto"
    echo_
    echo_ " Usage: toast update"
    echo_
    echo_ " Usage: toast config"
    echo_
    echo_ " Usage: toast init"
    echo_ " Usage: toast init master"
    echo_ " Usage: toast init slave"
    echo_ " Usage: toast init httpd"
    echo_ " Usage: toast init nginx"
    echo_ " Usage: toast init php5"
    echo_ " Usage: toast init php7"
    echo_ " Usage: toast init node"
    echo_ " Usage: toast init java"
    echo_ " Usage: toast init tomcat"
    echo_ " Usage: toast init mysql"
    echo_ " Usage: toast init redis"
    echo_
    echo_ " Usage: toast version"
    echo_ " Usage: toast version next"
    echo_ " Usage: toast version save"
    echo_
    echo_ " Usage: toast vhost"
    echo_ " Usage: toast vhost lb"
    echo_ " Usage: toast vhost fleet"
    echo_ " Usage: toast vhost domain"
    echo_
    echo_ " Usage: toast deploy"
    echo_ " Usage: toast deploy fleet"
    echo_ " Usage: toast deploy target {no}"
    echo_
    echo_ " Usage: toast health"
    echo_
    echo_ " Usage: toast ssh"
    echo_
    echo_bar
}

auto() {
    not_darwin

    echo_toast

    prepare

    config

    self_info

    init_hosts
    init_profile

    init_aws
    init_slave
    init_epel
    init_auto

    #init_startup

    deploy_fleet
    vhost_fleet
    nginx_lb
}

update() {
    config_save

    self_info
    self_update

    #service_update
}

config() {
    config_auto
    config_cron
}

init() {
    case ${PARAM1} in
        hosts)
            init_hosts
            ;;
        profile)
            init_profile
            ;;
        master)
            init_master
            ;;
        slave)
            init_slave
            ;;
        aws)
            init_aws
            ;;
        certificate)
            init_certificate "${PARAM2}"
            ;;
        startup)
            init_startup
            ;;
        httpd)
            init_httpd
            ;;
        nginx)
            init_nginx
            ;;
        php5|php55)
            init_php 55
            ;;
        php56)
            init_php 56
            ;;
        php7|php70)
            init_php 70
            ;;
        node|node4)
            init_node
            ;;
        java|java8)
            init_java8
            ;;
        tomcat|tomcat8)
            init_tomcat8
            ;;
        mysql)
            init_mysql55
            ;;
        redis)
            init_redis
            ;;
        rabbitmq)
            init_rabbitmq
            ;;
        docker)
            init_docker
            ;;
        munin)
            init_munin
            ;;
        jenkins)
            init_jenkins
            ;;
        *)
            self_info
            init_auto
    esac
}

version() {
    repo_path

    version_parse

    case ${PARAM1} in
        s|save)
            version_save
            ;;
        m|n|master|next)
            version_master
            ;;
        *)
            ;;
    esac
}

vhost() {
    not_darwin

    self_info

    init_hosts
    init_profile

    case ${PARAM1} in
        b|lb)
            nginx_lb
            ;;
        d|domain)
            vhost_domain
            ;;
        *)
            vhost_fleet
    esac
}

deploy() {
    not_darwin

    repo_path

    self_info

    init_hosts
    init_profile

    case ${PARAM1} in
        p|project)
            deploy_project
            ;;
        t|target)
            deploy_target
            ;;
        *)
            deploy_fleet
            vhost_fleet
    esac
}

log() {
    case ${PARAM1} in
        t|tomcat)
            log_tomcat
            ;;
        w|web)
            log_webapp
            ;;
        *)
            log_cron
    esac
}

health() {
    if [ "${SNO}" == "" ]; then
        warning "Not configured server. [${SNO}]"
        return
    fi

    #echo_ "server health..."

    UNAME=`uname -a`
    UPTIME=`uptime`
    CPU=`grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage}'`

    #echo_ "server uptime    [${UPTIME}]"
    #echo_ "server cpu usage [${CPU}]"

    URL="${TOAST_URL}/server/health/${SNO}"
    RES=`curl -s --data "org=${ORG}&token=${TOKEN}&id=${UUID}&cpu=${CPU}&uname=${UNAME}&uptime=${UPTIME}" ${URL}`
    ARR=(${RES})

    if [ "${ARR[0]}" == "OK" ]; then
        if [ "${ARR[2]}" != "" ]; then
            if [ "${ARR[2]}" != "${NAME}" ]; then
                config_name "${ARR[2]}"
                config_local
            fi
        fi
    fi

    exit 0
}

reset() {
    if [ "${SNO}" == "" ]; then
        warning "Not configured server. [${SNO}]"
        return
    fi

    URL="${TOAST_URL}/server/info/${SNO}"
    RES=`curl -s --data "org=${ORG}&token=${TOKEN}&id=${UUID}" ${URL}`
    ARR=(${RES})

    if [ "${ARR[0]}" == "OK" ]; then
        if [ "${ARR[2]}" != "" ]; then
            if [ "${ARR[2]}" != "${NAME}" ]; then
                config_name "${ARR[2]}"
                config_local
            fi
        fi
    fi
}

################################################################################

self_info() {
    echo_bar
    echo_ "OS    : ${OS_NAME} ${OS_TYPE}"
    echo_ "HOME  : ${HOME}"
    echo_bar
    echo_ "ORG   : ${ORG}"
    echo_ "PHASE : ${PHASE}"
    echo_ "FLEET : ${FLEET}"
    echo_ "NAME  : ${NAME}"
    echo_bar
}

self_update() {
    ${SHELL_DIR}/install.sh
}

prepare() {
    service_install "gcc curl wget unzip vim git telnet httpie"

    make_dir ${DATA_DIR}
    make_dir ${LOGS_DIR} 777

    # timezone
    ${SUDO} rm -rf /etc/localtime
    ${SUDO} ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime

    # i18n
    ${SUDO} cp -rf ${SHELL_DIR}/package/linux/i18n.txt /etc/sysconfig/i18n

    # selinux
#    ${SUDO} cp -rf ${SHELL_DIR}/package/linux/selinux.txt /etc/selinux/config

#    if command -v setenforce > /dev/null; then
#        echo_ "selinux disable..."
#        ${SUDO} setenforce 0
#    fi
}

config_auto() {
    # port
    if [ -r /etc/ssh/sshd_config ]; then
        SSH="`cat /etc/ssh/sshd_config | egrep ^\#?Port`"
    else
        SSH="`${SUDO} cat /etc/ssh/sshd_config | egrep ^\#?Port`"
    fi
    if [ "${SSH}" != "" ]; then
        ARR=(${SSH})
        PORT="${ARR[1]}"
    fi

    # .toast
    if [ ! -f "${CONFIG}" ]; then
        cp -rf ${SHELL_DIR}/package/toast.txt ${CONFIG}
        source ${CONFIG}
    fi

    #  fleet phase org token
    if [ "${PARAM1}" != "" ]; then
        FLEET="${PARAM1}"
    fi
    if [ "${PARAM2}" != "" ]; then
        PHASE="${PARAM2}"
    fi
    if [ "${PARAM3}" != "" ]; then
        ORG="${PARAM3}"
        TOAST_URL="http://${ORG}.toast.sh"
    fi
    if [ "${PARAM4}" != "" ]; then
        TOKEN="${PARAM4}"
    fi

    config_save
    config_info
}

config_save() {
    echo_bar
    echo_ "config save... [${UUID}][${SNO}]"

    URL="${TOAST_URL}/server/config"
    RES=`curl -s --data "org=${ORG}&token=${TOKEN}&phase=${PHASE}&fleet=${FLEET}&id=${UUID}&name=${NAME}&host=${HOST}&port=${PORT}&user=${USER}&no=${SNO}" ${URL}`
    ARR=(${RES})

    if [ "${ARR[0]}" == "OK" ]; then
        if [ "${ARR[1]}" != "" ]; then
            SNO="${ARR[1]}"
        fi
        if [ "${ARR[2]}" != "" ]; then
            HOST="${ARR[2]}"
        fi
        if [ "${ARR[3]}" != "" ]; then
            PHASE="${ARR[3]}"
        fi
        if [ "${ARR[4]}" != "" ]; then
            FLEET="${ARR[4]}"
        fi
        if [ "${ARR[5]}" != "" ]; then
            if [ "${ARR[5]}" != "${NAME}" ]; then
                config_name "${ARR[5]}"
            fi
        fi

        config_local
    else
        warning "Server Error. [${URL}][${RES}]"
    fi

    echo_bar
}

config_local() {
    echo_ "config local... [${SNO}][${NAME}]"

    echo "# toast config" > ${CONFIG}
    echo "TOAST_URL=\"${TOAST_URL}\"" >> ${CONFIG}
    echo "ORG=\"${ORG}\"" >> ${CONFIG}
    echo "PHASE=\"${PHASE}\"" >> ${CONFIG}
    echo "FLEET=\"${FLEET}\"" >> ${CONFIG}
    echo "UUID=\"${UUID}\"" >> ${CONFIG}
    echo "NAME=\"${NAME}\"" >> ${CONFIG}
    echo "HOST=\"${HOST}\"" >> ${CONFIG}
    echo "PORT=\"${PORT}\"" >> ${CONFIG}
    echo "USER=\"${USER}\"" >> ${CONFIG}
    echo "TOKEN=\"${TOKEN}\"" >> ${CONFIG}
    echo "SNO=\"${SNO}\"" >> ${CONFIG}

    chmod 644 ${CONFIG}
    source ${CONFIG}
}

config_name() {
    if [ "$1" == "" ]; then
        return
    fi

    NAME="$1"

    echo_ "hostname... [${NAME}]"

    if [ "${OS_TYPE}" == "el7" ]; then
        ${SUDO} hostnamectl set-hostname "${NAME}"
    else
        ${SUDO} hostname "${NAME}"

        mod_conf /etc/sysconfig/network "HOSTNAME" "${NAME}"
    fi
}

config_info() {
    if [ ! -f "${CONFIG}" ]; then
        warning "Not exist file. [${CONFIG}]"
        return
    fi

    echo_bar
    cat ${CONFIG}
    echo_bar
}

config_cron() {
    TEMP_FILE="${TEMP_DIR}/toast-cron.tmp"

    echo "# toast cron" > ${TEMP_FILE}
    echo "0 1 * * * ${SHELL_DIR}/toast.sh log > /dev/null 2>&1" >> ${TEMP_FILE}
    echo "0 5 * * * ${SHELL_DIR}/toast.sh update > /dev/null 2>&1" >> ${TEMP_FILE}
    echo "* * * * * ${SHELL_DIR}/toast.sh health > /dev/null 2>&1" >> ${TEMP_FILE}

    crontab ${TEMP_FILE}

    echo_bar
    crontab -l
    echo_bar
}

init_hosts() {
    echo_ "init hosts..."

    TARGET="/etc/hosts"
    TEMP_FILE="${TEMP_DIR}/toast-hosts.tmp"

    # backup
    if [ -f "${TARGET}_toast" ]; then
        copy "${TARGET}_toast" ${TARGET}
    else
        copy ${TARGET} "${TARGET}_toast"
    fi

    # hosts
    URL="${TOAST_URL}/server/hosts/${SNO}"
    RES=`curl -s --data "org=${ORG}&token=${TOKEN}&no=${SNO}" ${URL}`

    if [ "${RES}" != "" ]; then
        echo "${RES}" > ${TEMP_FILE}
        copy ${TEMP_FILE} ${TARGET}
    fi
}

init_profile() {
    echo_ "init profile..."

    TARGET="${HOME}/.toast_profile"

    add_source ${TARGET}

    # profile
    URL="${TOAST_URL}/server/profile/${SNO}"
    RES=`curl -s --data "org=${ORG}&token=${TOKEN}&no=${SNO}" ${URL}`

    if [ "${RES}" != "" ]; then
        echo "${RES}" > ${TARGET}
        source ${TARGET}
    fi
}

init_master() {
    echo_ "init master..."

    mkdir ${HOME}/.ssh
    mkdir ${HOME}/.aws

    # .ssh/id_rsa
    URL="${TOAST_URL}/config/key/rsa_private_key"
    RES=`curl -s --data "org=${ORG}&token=${TOKEN}&no=${SNO}" ${URL}`

    if [ "${RES}" != "" ]; then
        TARGET="${HOME}/.ssh/id_rsa"
        echo "${RES}" > ${TARGET}
        chmod 600 ${TARGET}
    fi

    # .ssh/id_rsa.pub
    URL="${TOAST_URL}/config/key/rsa_public_key"
    RES=`curl -s --data "org=${ORG}&token=${TOKEN}&no=${SNO}" ${URL}`

    if [ "${RES}" != "" ]; then
        TARGET="${HOME}/.ssh/id_rsa.pub"
        echo "${RES}" > ${TARGET}
        chmod 644 ${TARGET}
    fi

    # .aws/credentials
    URL="${TOAST_URL}/config/key/aws_master"
    RES=`curl -s --data "org=${ORG}&token=${TOKEN}&no=${SNO}" ${URL}`

    if [ "${RES}" != "" ]; then
        TARGET="${HOME}/.aws/credentials"
        echo "${RES}" > ${TARGET}
        chmod 600 ${TARGET}
    fi
}

init_slave() {
    echo_ "init slave..."

    mkdir ${HOME}/.ssh
    mkdir ${HOME}/.aws

    # .ssh/authorized_keys
    TARGET="${HOME}/.ssh/authorized_keys"
    touch ${TARGET}

    if [ `cat ${TARGET} | grep -c "toast@yanolja.in"` -eq 0 ]; then
        URL="${TOAST_URL}/config/key/rsa_public_key"
        RES=`curl -s --data "org=${ORG}&token=${TOKEN}&no=${SNO}" ${URL}`

        if [ "${RES}" != "" ]; then
            echo "${RES}" >> ${TARGET}
            chmod 700 ${TARGET}
        fi
    fi

    # .ssh/id_rsa
    TARGET="${HOME}/.ssh/id_rsa"
    rm -rf ${TARGET}

    # .ssh/id_rsa.pub
    TARGET="${HOME}/.ssh/id_rsa.pub"
    rm -rf ${TARGET}

    # .ssh/config
    URL="${TOAST_URL}/config/key/ssh_config"
    RES=`curl -s --data "org=${ORG}&token=${TOKEN}&no=${SNO}" ${URL}`

    if [ "${RES}" != "" ]; then
        TARGET="${HOME}/.ssh/config"
        echo "${RES}" > ${TARGET}
        chmod 600 ${TARGET}
    fi

    # .aws/credentials
    URL="${TOAST_URL}/config/key/aws_slave"
    RES=`curl -s --data "org=${ORG}&token=${TOKEN}&no=${SNO}" ${URL}`

    if [ "${RES}" != "" ]; then
        TARGET="${HOME}/.aws/credentials"
        echo "${RES}" > ${TARGET}
        chmod 600 ${TARGET}
    fi

    # master
    if [ "${PHASE}" == "build" ]; then
        init_master
    fi
}

init_aws() {
    echo_ "init aws..."

    mkdir ${HOME}/.aws

    # .aws/config
    URL="${TOAST_URL}/config/key/aws_config"
    RES=`curl -s --data "org=${ORG}&token=${TOKEN}&no=${SNO}" ${URL}`

    if [ "${RES}" != "" ]; then
        TARGET="${HOME}/.aws/config"
        echo "${RES}" > ${TARGET}
        chmod 600 ${TARGET}
    fi

    # aws cli
    if ! command -v aws > /dev/null; then
        if [ ! -f "${SHELL_DIR}/.config_aws" ]; then
            echo_ "init aws cli..."

            wget -q -N https://s3.amazonaws.com/aws-cli/awscli-bundle.zip

            if [ -f "${HOME}/awscli-bundle.zip" ]; then
                unzip -q awscli-bundle.zip

                AWS_HOME="/usr/local/aws"

                ${SUDO} ./awscli-bundle/install -i ${AWS_HOME} -b /usr/bin/aws

                add_path "${AWS_HOME}/bin"

                rm -rf awscli-bundle
                rm -rf awscli-bundle.zip

                touch "${SHELL_DIR}/.config_aws"
            fi
        fi
    fi

    echo_bar
    echo_ "`aws --version`"
    echo_bar
}

init_certificate() {
    if [ "$1" == "" ]; then
        return
    fi

    PARAM="$1"

    echo_ "init certificate... [${PARAM}]"

    SSL_DIR="/data/conf"
    make_dir ${SSL_DIR}

    SSL_NAME=
    SSL_INFO="${SSL_DIR}/info"

    if [ -f ${SSL_INFO} ]; then
        source ${SSL_INFO}
    fi

    if [ "${PARAM}" == "${SSL_NAME}" ]; then
        return
    fi

    CERTIFICATE="${TEMP_DIR}/${PARAM}"

    URL="${TOAST_URL}/certificate/name/${PARAM}"
    wget -q -N --post-data "org=${ORG}&token=${TOKEN}&no=${SNO}" -P "${TEMP_DIR}" "${URL}"

    if [ -f ${CERTIFICATE} ]; then
        echo_ "save certificate..."

        TARGET=

        while read line
        do
            ARR=(${line})

            if [ "${ARR[0]}" == "#" ]; then
                TARGET="${SSL_DIR}/${ARR[1]}"
                new_file ${TARGET} 600
            else
                if [ -w ${TARGET} ]; then
                    echo "${line}" >> ${TARGET}
                fi
            fi
        done < ${CERTIFICATE}

        echo "SSL_NAME=${PARAM}" > ${SSL_INFO}
    fi
}

init_startup() {
    TARGET="/etc/rc.d/rc.local"

    RC_HEAD="# toast auto"

    HAS_LINE="false"

    while read LINE
    do
        if [ "${LINE}" == "${RC_HEAD}" ]; then
            HAS_LINE="true"
        fi
    done < ${TARGET}

    if [ "${HAS_LINE}" == "false" ]; then
        TEMP_FILE="${TEMP_DIR}/toast-service.tmp"

        copy ${TARGET} ${TEMP_FILE}

        echo "" >> ${TEMP_FILE}
        echo "${RC_HEAD}" >> ${TEMP_FILE}
        echo "/sbin/runuser -l ${USER} -c '/home/${USER}/toaster/toast.sh update'" >> ${TEMP_FILE}
        echo "/sbin/runuser -l ${USER} -c '/home/${USER}/toaster/toast.sh auto'" >> ${TEMP_FILE}
        echo "" >> ${TEMP_FILE}

        copy ${TEMP_FILE} ${TARGET} 755
    fi
}

init_auto() {
    URL="${TOAST_URL}/server/apps/${SNO}"
    RES=`curl -s --data "org=${ORG}&token=${TOKEN}&no=${SNO}" ${URL}`
    ARR=(${RES})

    for VAL in "${ARR[@]}"; do
        case "${VAL}" in
            httpd)
                init_httpd
                ;;
            nginx)
                init_nginx
                ;;
            php5|php55)
                init_php 55
                ;;
            php56)
                init_php 56
                ;;
            php7|php70)
                init_php 70
                ;;
            node|node4)
                init_node
                ;;
            java|java8)
                init_java8
                ;;
            tomcat|tomcat8)
                init_tomcat8
                ;;
            mysql55)
                init_mysql55
                ;;
            mysql|mysql56)
                init_mysql56
                ;;
            redis)
                init_redis
                ;;
            rabbitmq)
                init_rabbitmq
                ;;
        esac
    done
}

init_script() {
    TARGET="${HOME}/.toast_script"

    # script
    URL="${TOAST_URL}/server/script/${SNO}"
    RES=`curl -s --data "org=${ORG}&token=${TOKEN}&no=${SNO}" ${URL}`

    if [ "${RES}" != "" ]; then
        echo "${RES}" > ${TARGET}
        chmod 755 ${TARGET}
    fi
}

init_epel() {
    if [ -f "${SHELL_DIR}/.config_epel" ]; then
        return 1
    fi

    service_install yum-utils

    if [ "${OS_TYPE}" == "el7" ]; then
        ${SUDO} rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    else
        ${SUDO} rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm
    fi

    ${SUDO} yum-config-manager --enable epel

    touch "${SHELL_DIR}/.config_epel"
}

init_webtatic() {
    if [ -f "${SHELL_DIR}/.config_webtatic" ]; then
        return 1
    fi

    status=`${SUDO} yum list | grep php56 | wc -l | awk '{print $1}'`

    if [ ${status} -lt 1 ]; then
        if [ "${OS_TYPE}" == "el7" ]; then
            ${SUDO} rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
        else
            ${SUDO} rpm -Uvh https://mirror.webtatic.com/yum/el6/latest.rpm
        fi
    fi

    touch "${SHELL_DIR}/.config_webtatic"
}

init_httpd() {
    if [ ! -f "${SHELL_DIR}/.config_httpd" ]; then
        echo_ "init httpd..."

        service_install "openssl openssl-devel"

        status=`${SUDO} yum list | grep httpd24 | wc -l | awk '{print $1}'`

        if [ ${status} -ge 1 ]; then
            service_install "httpd24"
        else
            service_install "httpd"
        fi

        VERSION=$(httpd -version | egrep -o "Apache\/2.4")

        if [ "${VERSION}" != "" ]; then
            HTTPD_VERSION="24"
        else
            HTTPD_VERSION="22"
        fi

        custom_httpd_conf

        vhost_local

        echo_ "httpd start..."
        service_ctl httpd start on

        echo "HTTPD_VERSION=${HTTPD_VERSION}" > "${SHELL_DIR}/.config_httpd"
    fi

    if [ -d "/var/www/html" ]; then
        TEMP_FILE="${TEMP_DIR}/toast-health.tmp"
        echo "OK ${HOST}" > ${TEMP_FILE}
        copy ${TEMP_FILE} "/var/www/html/index.html"
        copy ${TEMP_FILE} "/var/www/html/health.html"
    fi

    make_dir "${SITE_DIR}"
    make_dir "${SITE_DIR}/files" 777
    make_dir "${SITE_DIR}/upload" 777

    echo_bar
    echo_ "`httpd -version`"
    echo_bar
}

init_nginx() {
    if [ ! -f "${SHELL_DIR}/.config_nginx" ]; then
        echo_ "init nginx..."

        repo_path

        ${SHELL_DIR}/install/nginx.sh ${REPO_PATH}

        echo_ "nginx start..."
        ${SUDO} nginx

        touch "${SHELL_DIR}/.config_nginx"
    fi

    if [ -d "/usr/local/nginx/html" ]; then
        TEMP_FILE="${TEMP_DIR}/toast-health.tmp"
        echo "OK ${NAME}" > ${TEMP_FILE}
        copy ${TEMP_FILE} "/usr/local/nginx/html/index.html"
        copy ${TEMP_FILE} "/usr/local/nginx/html/health.html"
    fi

    make_dir "${SITE_DIR}"
    make_dir "${SITE_DIR}/files" 777
    make_dir "${SITE_DIR}/upload" 777

    echo_bar
    echo_ "`nginx -v`"
    echo_bar
}

init_php() {
    if [ ! -f "${SHELL_DIR}/.config_php" ]; then
        init_webtatic

        VERSION="$1"

        echo_ "init php${VERSION}..."

        status=`${SUDO} yum list | grep php${VERSION}w | wc -l | awk '{print $1}'`

        if [ ${status} -ge 1 ]; then
            service_install "php${VERSION}w php${VERSION}w-mysqlnd php${VERSION}w-mcrypt php${VERSION}w-gd php${VERSION}w-mbstring php${VERSION}w-bcmath"
        else
            service_install "php${VERSION} php${VERSION}-mysqlnd php${VERSION}-mcrypt php${VERSION}-gd php${VERSION}-mbstring php${VERSION}-bcmath"
        fi

        custom_php_ini

        httpd_restart

        echo "PHP_VERSION=${VERSION}" > "${SHELL_DIR}/.config_php"
    fi

    echo_bar
    echo_ "`php -version`"
    echo_bar
}

init_node() {
    if [ ! -f "${SHELL_DIR}/.config_node" ]; then
        echo_ "init node..."

        repo_path

        ${SHELL_DIR}/install/node.sh ${REPO_PATH}

        NODE_HOME="/usr/local/node"

        add_path "${NODE_HOME}/bin"
        mod_env "NODE_HOME" "${NODE_HOME}"

        echo "NODE_HOME=${NODE_HOME}"
        echo "NODE_HOME=${NODE_HOME}" > "${SHELL_DIR}/.config_node"
    fi

    echo_bar
    echo_ "node version `node -v`"
    echo_ "npm version `npm -v`"
    echo_bar
}

init_java8() {
    if [ ! -f "${SHELL_DIR}/.config_java" ]; then
        echo_ "init java..."

        repo_path

        service_remove "java-1.7.0-openjdk java-1.7.0-openjdk-headless"
        service_remove "java-1.8.0-openjdk java-1.8.0-openjdk-headless java-1.8.0-openjdk-devel"

        ${SHELL_DIR}/install/java.sh ${REPO_PATH}

        JAVA_HOME="/usr/local/java"

        add_path "${JAVA_HOME}/bin"
        mod_env "JAVA_HOME" "${JAVA_HOME}"

        echo "JAVA_HOME=${JAVA_HOME}"
        echo "JAVA_HOME=${JAVA_HOME}" > "${SHELL_DIR}/.config_java"
    fi

    make_dir "${APPS_DIR}"

    echo_bar
    echo_ "`java -version`"
    echo_bar
}

init_tomcat8() {
    if [ ! -f "${SHELL_DIR}/.config_tomcat" ]; then
        echo_ "init tomcat..."

        repo_path

        ${SHELL_DIR}/install/tomcat.sh ${REPO_PATH}

        CATALINA_HOME="${APPS_DIR}/tomcat8"

        mod_env "CATALINA_HOME" "${CATALINA_HOME}"

        cp -rf "${CATALINA_HOME}/conf/web.xml" "${CATALINA_HOME}/conf/web.org.xml"
        cp -rf "${SHELL_DIR}/package/tomcat/web.xml" "${CATALINA_HOME}/conf/web.xml"

        echo "CATALINA_HOME=${CATALINA_HOME}"
        echo "CATALINA_HOME=${CATALINA_HOME}" > "${SHELL_DIR}/.config_tomcat"
    fi
}

init_mysql55() {
    if [ ! -f "${SHELL_DIR}/.config_mysql" ]; then
        echo_ "init mysql55..."

        service_install mysql55-server

        service_ctl mysqld start on

        touch "${SHELL_DIR}/.config_mysql"
    fi
}

init_mysql56() {
    if [ ! -f "${SHELL_DIR}/.config_mysql" ]; then
        echo_ "init mysql56..."

        service_install mysql56-server

        service_ctl mysqld start on

        touch "${SHELL_DIR}/.config_mysql"
    fi
}

init_redis() {
    if [ ! -f "${SHELL_DIR}/.config_redis" ]; then
        echo_ "init redis..."

        service_install redis

        service_ctl redis start on

        touch "${SHELL_DIR}/.config_redis"
    fi
}

init_rabbitmq() {
    if [ ! -f "${SHELL_DIR}/.config_rabbitmq" ]; then
        echo_ "init rabbitmq..."

        repo_path

        ${SHELL_DIR}/install/rabbitmq.sh ${REPO_PATH}

        service_ctl rabbitmq-server start on

        ${SUDO} rabbitmq-plugins enable rabbitmq_management
        ${SUDO} rabbitmq-plugins enable rabbitmq_delayed_message_exchange

        ${SUDO} rabbitmqctl add_user rabbitmq rabbitmq
        ${SUDO} rabbitmqctl set_user_tags rabbitmq administrator

        ${SUDO} rabbitmqctl add_user pushservice pushservice

        touch "${SHELL_DIR}/.config_rabbitmq"
    fi
}

init_docker() {
    if [ ! -f "${SHELL_DIR}/.config_docker" ]; then
        echo_ "init docker..."

        service_install docker

        service_ctl docker start on

        touch "${SHELL_DIR}/.config_docker"
    fi
}

init_munin() {
    if [ ! -f "${SHELL_DIR}/.config_munin" ]; then
        echo_ "init munin..."

        service_install munin

        service_ctl munin-node start on

        touch "${SHELL_DIR}/.config_munin"
    fi
}

init_jenkins() {
    if [ ! -f "${SHELL_DIR}/.config_tomcat" ]; then
        warning "Not set tomcat."
        return 1
    fi

    HAS_WAR="TRUE"

    tomcat_stop

    rm -rf ${WEBAPP_DIR}/jenkins.war
    rm -rf ${WEBAPP_DIR}/jenkins

    echo_ "download jenkins..."

    # jenkins
    URL="http://mirrors.jenkins.io/war/latest/jenkins.war"
    wget -q -N -P "${WEBAPP_DIR}" "${URL}"

    cp -rf "${CATALINA_HOME}/conf/web.org.xml" "${CATALINA_HOME}/conf/web.xml"

    # composer
    if ! command -v composer > /dev/null; then
        curl -sS https://getcomposer.org/installer | php
        sudo mv composer.phar /usr/local/bin/composer
    fi
    # swagger
    if command -v composer > /dev/null; then
        composer global require zircote/swagger-php
    fi

    tomcat_start
}

custom_httpd_conf() {
    if [ -f "/etc/httpd/conf/httpd.conf" ]; then
        HTTPD_CONF="/etc/httpd/conf/httpd.conf"
    else
        if [ -f "/usr/local/apache/conf/httpd.conf" ]; then
            HTTPD_CONF="/usr/local/apache/conf/httpd.conf"
        fi
    fi

    if [ -f ${HTTPD_CONF} ]; then
        echo_ "${HTTPD_CONF}"

        TEMP_FILE="${TEMP_DIR}/toast-httpd-conf.tmp"

        # User apache
        sed "s/User\ apache/User\ $USER/g" ${HTTPD_CONF} > ${TEMP_FILE}
        copy ${TEMP_FILE} ${HTTPD_CONF}

        # Group apache
        sed "s/Group\ apache/Group\ $USER/g" ${HTTPD_CONF} > ${TEMP_FILE}
        copy ${TEMP_FILE} ${HTTPD_CONF}
    fi
}

custom_php_ini() {
    if [ -f "/etc/php.ini" ]; then
        PHP_INI="/etc/php.ini"
    fi

    if [ -f ${PHP_INI} ]; then
        echo_ "${PHP_INI}"

        TEMP_FILE="${TEMP_DIR}/toast-php-ini.tmp"

        # short_open_tag = On
        sed "s/short\_open\_tag\ \=\ Off/short\_open\_tag\ \=\ On/g" ${PHP_INI} > ${TEMP_FILE}
        copy ${TEMP_FILE} ${PHP_INI} 644

        # expose_php = Off
        sed "s/expose\_php\ \=\ On/expose\_php\ \=\ Off/g" ${PHP_INI} > ${TEMP_FILE}
        copy ${TEMP_FILE} ${PHP_INI} 644

        # date.timezone = Asia/Seoul
        sed "s/\;date\.timezone\ \=/date\.timezone\ \=\ Asia\/Seoul/g" ${PHP_INI} > ${TEMP_FILE}
        copy ${TEMP_FILE} ${PHP_INI} 644

        # upload_max_filesize = 20M
        sed "s/\;upload\_max\_filesize\ \=\ 2M/upload\_max\_filesize\ \=\ 20M/g" ${PHP_INI} > ${TEMP_FILE}
        copy ${TEMP_FILE} ${PHP_INI} 644
    fi
}

version_parse() {
    POM_FILE="./pom.xml"

    if [ ! -f "${POM_FILE}" ]; then
        warning "Not exist file. [${POM_FILE}]"
        return 1
    fi

    ARR_GROUP=($(cat ${POM_FILE} | grep -oP '(?<=groupId>)[^<]+'))
    ARR_ARTIFACT=($(cat ${POM_FILE} | grep -oP '(?<=artifactId>)[^<]+'))
    ARR_VERSION=($(cat ${POM_FILE} | grep -oP '(?<=version>)[^<]+'))

    if [ "${ARR_GROUP[0]}" == "" ]; then
        warning "groupId does not exist. [${ARR_GROUP[0]}]"
        exit 1
    fi
    if [ "${ARR_ARTIFACT[0]}" == "" ]; then
        warning "artifactId does not exist. [${ARR_ARTIFACT[0]}]"
        exit 1
    fi

    GROUP_ID=${ARR_GROUP[0]}
    ARTIFACT_ID=${ARR_ARTIFACT[0]}
    VERSION=${ARR_VERSION[0]}
    PACKAGE="${PARAM2}"

    echo_ "groupId=${GROUP_ID}"
    echo_ "artifactId=${ARTIFACT_ID}"
    echo_ "version=${VERSION}"

    GROUP_PATH=`echo "${GROUP_ID}" | sed "s/\./\//"`
}

version_master() {
    if [ "${ARTIFACT_ID}" == "" ]; then
        warning "Not set artifact_id. [${ARTIFACT_ID}]"
        return 1
    fi

    echo_ "version get..."

    URL="${TOAST_URL}/version/latest/${ARTIFACT_ID}"
    RES=`curl -s --data "org=${ORG}&token=${TOKEN}&groupId=${GROUP_ID}&artifactId=${ARTIFACT_ID}&packaging=${PACKAGE}&no=${SNO}" ${URL}`
    ARR=(${RES})

    if [ "${ARR[0]}" != "OK" ]; then
        warning "Server Error. [${URL}][${RES}]"
        return 1
    fi

    VERSION="${ARR[1]}"

    echo_ "version=${VERSION}"

    DATE=`date +%Y-%m-%d" "%H:%M`

    git tag -a "${VERSION}" -m "at ${DATE} by toast"
    git push origin "${VERSION}"

    version_replace
}

version_replace() {
    VER1="<version>[0-9a-zA-Z\.\-]\+<\/version>"
    VER2="<version>${VERSION}<\/version>"

    TEMP_FILE="${TEMP_DIR}/toast-pom.tmp"

    if [ -f ${POM_FILE} ]; then
        sed "s/$VER1/$VER2/;10q;" ${POM_FILE} > ${TEMP_FILE}
        sed "1,10d" ${POM_FILE} >> ${TEMP_FILE}

        cp -rf ${TEMP_FILE} ${POM_FILE}
    fi
}

version_save() {
    if [ "${ARTIFACT_ID}" == "" ]; then
        warning "Not set artifact_id. [${ARTIFACT_ID}]"
        return 1
    fi

    echo_ "version save..."

    PACKAGE_PATH=""
    if [ -d "target" ]; then
        if [ -f "target/${ARTIFACT_ID}-${VERSION}.war" ]; then
            PACKAGE_PATH="target/${ARTIFACT_ID}-${VERSION}.war"
        fi
        if [ -f "target/${ARTIFACT_ID}-${VERSION}.jar" ]; then
            PACKAGE_PATH="target/${ARTIFACT_ID}-${VERSION}.jar"
        fi
    fi

    if [ "${PACKAGE_PATH}" == "" ]; then
        warning "package does not exist. [${PACKAGE_PATH}]"
        return 1
    fi

    UPLOAD_PATH="${REPO_PATH}/maven2/${GROUP_PATH}/${ARTIFACT_ID}/${VERSION}/"

    echo_ "--> from: ${PACKAGE_PATH}"
    echo_ "--> to  : ${UPLOAD_PATH}"

    if [ "${PARAM2}" == "public" ]; then
        OPTION="--quiet --grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers"
    else
        OPTION="--quiet " # --quiet
    fi

    aws s3 cp ${PACKAGE_PATH} ${UPLOAD_PATH} ${OPTION}

    echo_ "package uploaded."

    NOTE=$(version_note)

    URL="${TOAST_URL}/version/build/${ARTIFACT_ID}/${VERSION}"
    RES=`curl -s --data "org=${ORG}&token=${TOKEN}&groupId=${GROUP_ID}&artifactId=${ARTIFACT_ID}&packaging=${PACKAGE}&no=${SNO}&note=${NOTE}" ${URL}`
    ARR=(${RES})

    if [ "${ARR[0]}" != "OK" ]; then
        warning "Server Error. [${URL}][${RES}]"
    fi
}

version_note() {
    git log --pretty=format:"- %s" --since=12hour | grep -v "\- Merge pull request " | grep -v "\- Merge branch "
}

nginx_conf_dir() {
    TOAST_NGINX="${SHELL_DIR}/.config_nginx"
    if [ ! -f "${TOAST_NGINX}" ]; then
        return 1
    fi

    NGINX_CONF_DIR=""

    if [ -f "/usr/local/nginx/conf/nginx.conf" ]; then
        NGINX_CONF_DIR="/usr/local/nginx/conf"
    fi
}

httpd_conf_dir() {
    TOAST_APACHE="${SHELL_DIR}/.config_httpd"
    if [ -f "${TOAST_APACHE}" ]; then
        source ${TOAST_APACHE}
    fi

    if [ "${HTTPD_VERSION}" == "" ]; then
        HTTPD_VERSION="22"
    fi

    HTTPD_CONF_DIR=""

    if [ -d "/etc/httpd/conf.d" ]; then
        HTTPD_CONF_DIR="/etc/httpd/conf.d"
    else
        if [ -d "/usr/local/apache/conf/extra" ]; then
            HTTPD_CONF_DIR="/usr/local/apache/conf/extra"
        fi
    fi
}

nginx_lb() {
    nginx_conf_dir

    if [ "${NGINX_CONF_DIR}" == "" ]; then
        return
    fi

    TEMP_FILE="${TEMP_DIR}/toast-lb.tmp"
    TARGET="${NGINX_CONF_DIR}/nginx.conf"

    echo_bar
    echo_ "nginx lb..."

    TARGET_DIR="${TEMP_DIR}/conf"
    mkdir -p ${TARGET_DIR}

    LB_CONF="${TARGET_DIR}/${SNO}"
    rm -rf ${LB_CONF}

    URL="${TOAST_URL}/server/lb/${SNO}"
    wget -q -N --post-data "org=${ORG}&token=${TOKEN}&no=${SNO}" -P "${TARGET_DIR}" "${URL}"

    if [ -f ${LB_CONF} ]; then
        echo_ "`cat ${LB_CONF}`"

        TEMP_HTTP="${TARGET_DIR}/toast-lb-http.tmp"
        TEMP_SSL="${TARGET_DIR}/toast-lb-ssl.tmp"
        TEMP_TCP="${TARGET_DIR}/toast-lb-tcp.tmp"

        rm -rf ${TEMP_FILE} ${TEMP_HTTP} ${TEMP_SSL} ${TEMP_TCP}

        while read line
        do
            ARR=(${line})

            if [ "${ARR[0]}" == "NO" ]; then
                FNO="${ARR[1]}"
            fi

            if [ "${ARR[0]}" == "SSL" ]; then
                init_certificate "${ARR[1]}"
            fi

            if [ "${ARR[0]}" == "HOST" ]; then
                HOST_ARR=(${line:5})
            fi

            if [ "${ARR[0]}" == "CUSTOM" ]; then
                URL="${TOAST_URL}/fleet/custom/${FNO}"
                RES=`curl -s --data "org=${ORG}&token=${TOKEN}&no=${SNO}" ${URL}`

                if [ "${RES}" != "" ]; then
                    CUSTOM="${RES}"
                fi
            fi

            if [ "${ARR[0]}" == "HTTP" ]; then
                PORT="${ARR[1]}"

                echo "    upstream toast {" >> ${TEMP_HTTP}

                for i in "${HOST_ARR[@]}"
                do
                   echo "        server ${i}:${PORT} max_fails=3 fail_timeout=10s;" >> ${TEMP_HTTP}
                done

                echo "    }" >> ${TEMP_HTTP}

                TEMPLATE="${SHELL_DIR}/package/nginx/nginx-http-server.conf"
                if [ "${CUSTOM}" == "" ]; then
                    sed "s/PORT/$PORT/g" ${TEMPLATE} >> ${TEMP_HTTP}
                else
                    sed "s/PORT/$PORT/;5q;" ${TEMPLATE} >> ${TEMP_HTTP}
                    echo "${CUSTOM}" >> ${TEMP_HTTP}
                    sed "1,9d" ${TEMPLATE} >> ${TEMP_HTTP}
                fi
            fi

            if [ "${ARR[0]}" == "HTTPS" ]; then
                PORT="${ARR[1]}"

                TEMPLATE="${SHELL_DIR}/package/nginx/nginx-http-ssl.conf"
                if [ "${CUSTOM}" == "" ]; then
                    sed "s/PORT/$PORT/g" ${TEMPLATE} > ${TEMP_SSL}
                else
                    sed "s/PORT/$PORT/;4q;" ${TEMPLATE} >> ${TEMP_SSL}
                    echo "${CUSTOM}" >> ${TEMP_SSL}
                    sed "1,8d" ${TEMPLATE} >> ${TEMP_SSL}
                fi
            fi

            if [ "${ARR[0]}" == "TCP" ]; then
                PORT="${ARR[1]}"

                echo "    upstream toast_${PORT} {" >> ${TEMP_TCP}

                for i in "${HOST_ARR[@]}"
                do
                   echo "        server ${i}:${PORT} max_fails=3 fail_timeout=10s;" >> ${TEMP_TCP}
                done

                echo "    }" >> ${TEMP_TCP}

                TEMPLATE="${SHELL_DIR}/package/nginx/nginx-tcp-server.conf"
                sed "s/PORT/$PORT/g" ${TEMPLATE} >> ${TEMP_TCP}
            fi
        done < ${LB_CONF}

        echo_ "assemble..."

        # default
        TEMPLATE="${SHELL_DIR}/package/nginx/nginx-default.conf"
        cat ${TEMPLATE} >> ${TEMP_FILE}

        # http
        if [ -f ${TEMP_HTTP} ]; then
            echo "" >> ${TEMP_FILE}
            echo "http {" >> ${TEMP_FILE}

            TEMPLATE="${SHELL_DIR}/package/nginx/nginx-http-default.conf"
            cat ${TEMPLATE} >> ${TEMP_FILE}

            # http
            echo "" >> ${TEMP_FILE}
            cat ${TEMP_HTTP} >> ${TEMP_FILE}

            # https
            if [ -f ${TEMP_SSL} ]; then
                echo "" >> ${TEMP_FILE}
                cat ${TEMP_SSL} >> ${TEMP_FILE}
            fi

            echo "}" >> ${TEMP_FILE}
        fi

        # tcp
        if [ -f ${TEMP_TCP} ]; then
            echo "stream {" >> ${TEMP_FILE}

            TEMPLATE="${SHELL_DIR}/package/nginx/nginx-tcp-default.conf"
            cat ${TEMPLATE} >> ${TEMP_FILE}

            echo "" >> ${TEMP_FILE}
            cat ${TEMP_TCP} >> ${TEMP_FILE}

            echo "}" >> ${TEMP_FILE}
        fi

        # done
        copy ${TEMP_FILE} ${TARGET} 644

        ${SUDO} nginx -s reload
    fi

    echo_bar
}

vhost_local() {
    httpd_conf_dir

    if [ "${HTTPD_CONF_DIR}" == "" ]; then
        return
    fi

    # localhost
    TEMPLATE="${SHELL_DIR}/package/apache/${HTTPD_VERSION}/localhost.conf"
    if [ -f "${TEMPLATE}" ]; then
        copy ${TEMPLATE} "${HTTPD_CONF_DIR}/localhost.conf" 644
    fi
}

vhost_replace() {
    DIR="$1"
    DOM="$1"

    if [ "${DOM}" == "" ]; then
        warning "--> empty.domain.com"
        return
    fi

    echo_ "--> ${DOM}"

    TEMPLATE="${SHELL_DIR}/package/apache/${HTTPD_VERSION}/vhost.conf"
    TEMP_FILE1="${TARGET_DIR}/toast-vhost1.tmp"
    TEMP_FILE2="${TARGET_DIR}/toast-vhost2.tmp"

    make_dir "${SITE_DIR}/${DIR}"

    # gen vhost
    DEST_FILE="${HTTPD_CONF_DIR}/toast-${DOM}.conf"
    sed "s/DIR/$DIR/g" ${TEMPLATE}   > ${TEMP_FILE1}
    sed "s/DOM/$DOM/g" ${TEMP_FILE1} > ${TEMP_FILE2}
    copy ${TEMP_FILE2} ${DEST_FILE}

    # vhost-in.com
    IN="${DOM}"
    IN=`echo "${IN}" | sed "s/yanolja\.com/yanolja-in\.com/"`
    IN=`echo "${IN}" | sed "s/yanoljanow\.com/yanoljanow-in\.com/"`

    if [ "${IN}" == "${DOM}" ]; then
        return
    fi

    # gen vhost
    DEST_FILE="${HTTPD_CONF_DIR}/toast-${DOM}.conf"
    sed "s/DIR/$DIR/g" ${TEMPLATE}   > ${TEMP_FILE1}
    sed "s/DOM/$DOM/g" ${TEMP_FILE1} > ${TEMP_FILE2}
    copy ${TEMP_FILE2} ${DEST_FILE}
}

vhost_domain() {
    httpd_conf_dir

    if [ "${HTTPD_CONF_DIR}" == "" ]; then
        return
    fi

    echo_bar
    echo_ "apache..."

    TARGET_DIR="${TEMP_DIR}/conf"
    mkdir -p ${TARGET_DIR}

    DOM="${PARAM2}"

    vhost_replace "${DOM}"

    httpd_graceful

    echo_bar
}

vhost_fleet() {
    httpd_conf_dir

    if [ "${HTTPD_CONF_DIR}" == "" ]; then
        return
    fi

    echo_bar
    echo_ "apache fleet..."

    vhost_local

    ${SUDO} rm -rf ${HTTPD_CONF_DIR}/toast*

    TARGET_DIR="${TEMP_DIR}/conf"
    mkdir -p ${TARGET_DIR}

    VHOST_LIST="${TARGET_DIR}/${SNO}"
    rm -rf ${VHOST_LIST}

    URL="${TOAST_URL}/server/vhost/${SNO}"
    wget -q -N --post-data "org=${ORG}&token=${TOKEN}&no=${SNO}" -P "${TARGET_DIR}" "${URL}"

    if [ -f ${VHOST_LIST} ]; then
        echo_ "placement apache..."

        while read line
        do
            ARR=(${line})

            DOM="${ARR[0]}"

            vhost_replace "${DOM}"
        done < ${VHOST_LIST}
    fi

    httpd_graceful

    echo_bar
}

repo_path() {
    if [ "${REPO_PATH}" != "" ]; then
        return
    fi

    # repo_path
    URL="${TOAST_URL}/config/key/repo_path"
    RES=`curl -s --data "org=${ORG}&token=${TOKEN}&no=${SNO}" ${URL}`

    if [ "${RES}" == "" ]; then
        warning "Not set repo_path. [${RES}]"
        return 1
    fi

    REPO_PATH="${RES}"
}

deploy_project() {
    echo_ "deploy project..."

    repo_path

    GROUP_ID="${PARAM2}"
    ARTIFACT_ID="${PARAM3}"
    VERSION="${PARAM4}"
    TYPE="${PARAM5}"
    DOMAIN="${PARAM6}"

    GROUP_PATH=`echo "${GROUP_ID}" | sed "s/\./\//"`

    PACKAGING="${TYPE}"
    if [ "${PACKAGING}" == "war" ]; then
        DEPLOY_PATH="${WEBAPP_DIR}"
    elif [ "${PACKAGING}" == "jar" ]; then
        DEPLOY_PATH="${APPS_DIR}"
    elif [ "${PACKAGING}" == "web" ] || [ "${PACKAGING}" == "php" ]; then
        PACKAGING="war"
        DEPLOY_PATH="${SITE_DIR}/${DOMAIN}"
    fi

    FILENAME="${ARTIFACT_ID}-${VERSION}.${PACKAGING}"
    FILEPATH="${TEMP_DIR}/${FILENAME}"

    UNZIP_DIR="${TEMP_DIR}/${ARTIFACT_ID}"

    echo_bar
    echo_ "download..."

    download

    tomcat_stop

    echo_ "placement..."

    placement

    tomcat_start

    echo_bar
}

deploy_target() {
    echo_bar
    echo_ "deploy target..."

    repo_path

    TARGET_DIR="${TEMP_DIR}/deploy"
    mkdir -p ${TARGET_DIR}

    TARGET_FILE="${TARGET_DIR}/${PARAM2}"
    rm -rf ${TARGET_FILE}

    URL="${TOAST_URL}/server/deploy/${SNO}/${PARAM2}"
    wget -q -N --post-data "org=${ORG}&token=${TOKEN}&no=${SNO}&t_no=${PARAM2}" -P "${TARGET_DIR}" "${URL}"

    if [ -f ${TARGET_FILE} ]; then
        echo_ "download..."

        while read line
        do
            ARR=(${line})

            deploy_value

            download
        done < ${TARGET_FILE}

        tomcat_stop

        echo_ "placement..."

        while read line
        do
            ARR=(${line})

            deploy_value

            placement
        done < ${TARGET_FILE}

        tomcat_start
    fi

    echo_bar
}

deploy_fleet() {
    echo_bar
    echo_ "deploy fleet..."

    repo_path

    TARGET_DIR="${TEMP_DIR}/deploy"
    mkdir -p ${TARGET_DIR}

    TARGET_FILE="${TARGET_DIR}/${SNO}"
    rm -rf ${TARGET_FILE}

    URL="${TOAST_URL}/server/deploy/${SNO}"
    wget -q -N --post-data "org=${ORG}&token=${TOKEN}&no=${SNO}" -P "${TARGET_DIR}" "${URL}"

    if [ -f ${TARGET_FILE} ]; then
        echo_ "download..."

        while read line
        do
            ARR=(${line})

            deploy_value

            download
        done < ${TARGET_FILE}

        tomcat_stop
        process_stop_all

        echo_ "placement..."

        while read line
        do
            ARR=(${line})

            deploy_value

            placement
        done < ${TARGET_FILE}

        tomcat_start
    fi

    echo_bar
}

deploy_value() {
    TNO="${ARR[0]}"
    GROUP_ID="${ARR[1]}"
    ARTIFACT_ID="${ARR[2]}"
    VERSION="${ARR[3]}"
    TYPE="${ARR[4]}"
    DOMAIN="${ARR[5]}"

    GROUP_PATH=`echo "${GROUP_ID}" | sed "s/\./\//"`

    PACKAGING="${TYPE}"
    DEPLOY_PATH=""

    if [ "${PACKAGING}" == "war" ]; then
        DEPLOY_PATH="${WEBAPP_DIR}"
    elif [ "${PACKAGING}" == "jar" ]; then
        DEPLOY_PATH="${APPS_DIR}"
    elif [ "${PACKAGING}" == "web" ] || [ "${PACKAGING}" == "php" ]; then
        PACKAGING="war"
        if [ "${DOMAIN}" != "" ]; then
            DEPLOY_PATH="${SITE_DIR}/${DOMAIN}"
        fi
    fi

    FILENAME="${ARTIFACT_ID}-${VERSION}.${PACKAGING}"
    FILEPATH="${TEMP_DIR}/${FILENAME}"

    UNZIP_DIR="${TEMP_DIR}/${TNO}"
}

download() {
    SOURCE="${REPO_PATH}/maven2/${GROUP_PATH}/${ARTIFACT_ID}/${VERSION}/${FILENAME}"

    echo_ "--> ${SOURCE}"

    aws s3 cp "${SOURCE}" "${TEMP_DIR}" --quiet

    if [ ! -f "${FILEPATH}" ]; then
        warning "deploy file does not exist. [${FILEPATH}]"
        return
    fi

    if [ "${TYPE}" == "jar" ]; then
        HAS_JAR="TRUE"
    elif [ "${TYPE}" == "war" ]; then
        HAS_WAR="TRUE"
    elif [ "${TYPE}" == "web" ] || [ "${TYPE}" == "php" ]; then
        if [ -d "${UNZIP_DIR}" ] || [ -f "${UNZIP_DIR}" ]; then
            rm -rf "${UNZIP_DIR}"
        fi

        if [ -d "${UNZIP_DIR}" ] || [ -f "${UNZIP_DIR}" ]; then
            warning "deploy file can not unzip. [${UNZIP_DIR}]"
        else
            unzip -q "${FILEPATH}" -d "${UNZIP_DIR}"

            if [ ! -d "${UNZIP_DIR}" ]; then
                warning "deploy file can not unzip. [${UNZIP_DIR}]"
            fi

            if [ -d "${UNZIP_DIR}/application/logs" ]; then
                chmod 777 "${UNZIP_DIR}/application/logs"
            fi
        fi
    fi
}

placement() {
    if [ "${DEPLOY_PATH}" == "" ]; then
        warning "--> /empty/deploy/path"
        return
    fi

    echo_ "--> ${DEPLOY_PATH}"

    if [ "${TYPE}" == "web" ] || [ "${TYPE}" == "php" ]; then
        rm -rf "${DEPLOY_PATH}.backup"

        if [ -d "${DEPLOY_PATH}" ] || [ -f "${DEPLOY_PATH}" ]; then
            mv -f "${DEPLOY_PATH}" "${DEPLOY_PATH}.backup"
        fi

        if [ -d "${DEPLOY_PATH}" ] || [ -f "${DEPLOY_PATH}" ]; then
            warning "deploy dir can not copy. [${DEPLOY_PATH}]"
        else
            mv -f "${UNZIP_DIR}" "${DEPLOY_PATH}"
        fi
    elif [ "${TYPE}" == "war" ]; then
        DEST_WAR="${DEPLOY_PATH}/${ARTIFACT_ID}.${PACKAGING}"

        rm -rf "${DEPLOY_PATH}/${ARTIFACT_ID}"
        rm -rf "${DEST_WAR}"

        if [ -d "${DEST_WAR}" ] || [ -f "${DEST_WAR}" ]; then
            warning "deploy file can not copy. [${DEST_WAR}]"
        else
            cp -rf "${FILEPATH}" "${DEST_WAR}"
        fi
    elif [ "${TYPE}" == "jar" ]; then
        DEST_WAR="${DEPLOY_PATH}/${ARTIFACT_ID}.${PACKAGING}"

        rm -rf "${DEST_WAR}"

        if [ -d "${DEST_WAR}" ] || [ -f "${DEST_WAR}" ]; then
            warning "deploy file can not copy. [${DEST_WAR}]"
        else
            process_stop
            cp -rf "${FILEPATH}" "${DEST_WAR}"
            process_start
        fi
    fi

    # version status
    URL="${TOAST_URL}/version/deploy/${ARTIFACT_ID}/${VERSION}"
    RES=`curl -s --data "org=${ORG}&token=${TOKEN}&phase=${PHASE}&fleet=${FLEET}&name=${NAME}&groupId=${GROUP_ID}&no=${SNO}&t_no=${TNO}" ${URL}`
    ARR=(${RES})

    if [ "${ARR[0]}" != "OK" ]; then
        warning "Server Error. [${URL}][${RES}]"
    fi
}

connect() {
    PHASE="${PARAM1}"
    FLEET="${PARAM2}"

    # phase
    if [ "${PHASE}" == "" ]; then
        URL="${TOAST_URL}/phase/conn"
        wget -q -N --post-data "org=${ORG}&token=${TOKEN}&no=${SNO}" -P "${TEMP_DIR}" "${URL}"

        CONN_LIST="${TEMP_DIR}/conn"

        if [ ! -f ${CONN_LIST} ]; then
            warning "Not exist file. [${CONN_LIST}]"
            exit 1
        fi

        echo_bar
        echo_ "# phase list"
        cat ${CONN_LIST}
        echo_bar

        if [ `cat ${CONN_LIST} | wc -l` -lt 2 ]; then
            while read line
            do
                ARR=(${line})

                if [ "${ARR[0]}" != "" ]; then
                    PHASE="${ARR[1]}"
                fi
            done < ${CONN_LIST}
        else
            echo "Please input phase no."
            read READ_NO

            while read line
            do
                ARR=(${line})

                if [ "${ARR[0]}" == "${READ_NO}" ]; then
                    PHASE="${ARR[1]}"
                fi
            done < ${CONN_LIST}
        fi

        if [ "${PHASE}" == "" ]; then
            return 1
        fi
    fi

    # fleet
    if [ "${FLEET}" == "" ]; then
        URL="${TOAST_URL}/fleet/conn/${PHASE}"
        wget -q -N --post-data "org=${ORG}&token=${TOKEN}&no=${SNO}" -P "${TEMP_DIR}" "${URL}"

        CONN_LIST="${TEMP_DIR}/${PHASE}"

        if [ ! -f ${CONN_LIST} ]; then
            warning "Not exist file. [${CONN_LIST}]"
            exit 1
        fi

        echo_bar
        echo_ "# fleet list"
        cat ${CONN_LIST}
        echo_bar

        if [ `cat ${CONN_LIST} | wc -l` -lt 2 ]; then
            while read line
            do
                ARR=(${line})

                if [ "${ARR[0]}" != "" ]; then
                    PHASE="${ARR[1]}"
                    FLEET="${ARR[2]}"
                fi
            done < ${CONN_LIST}
        else
            echo "Please input fleet no."
            read READ_NO

            while read line
            do
                ARR=(${line})

                if [ "${ARR[0]}" == "${READ_NO}" ]; then
                    PHASE="${ARR[1]}"
                    FLEET="${ARR[2]}"
                fi
            done < ${CONN_LIST}
        fi

        if [ "${FLEET}" == "" ]; then
            return 1
        fi
    fi

    # server
    URL="${TOAST_URL}/server/conn/${PHASE}/${FLEET}"
    wget -q -N --post-data "org=${ORG}&token=${TOKEN}&no=${SNO}" -P "${TEMP_DIR}" "${URL}"

    CONN_LIST="${TEMP_DIR}/${FLEET}"
    CONN_PARAM=""

    if [ ! -f ${CONN_LIST} ]; then
        warning "Not exist file. [${CONN_LIST}]"
        exit 1
    fi

    echo_bar
    echo_ "# server list"
    cat ${CONN_LIST}
    echo_bar

    if [ `cat ${CONN_LIST} | wc -l` -lt 2 ]; then
        while read line
        do
            ARR=(${line})

            if [ "${ARR[0]}" != "" ]; then
                CONN_PARAM="${ARR[1]}@${ARR[2]} -p ${ARR[3]}"
            fi
        done < ${CONN_LIST}
    else
        echo "Please input server no."
        read READ_NO

        while read line
        do
            ARR=(${line})

            if [ "${ARR[0]}" == "${READ_NO}" ]; then
                CONN_PARAM="${ARR[1]}@${ARR[2]} -p ${ARR[3]}"
            fi
        done < ${CONN_LIST}
    fi

    if [ "${CONN_PARAM}" == "" ]; then
        return 1
    fi

    echo_ "connect... ${CONN_PARAM}..."
    echo_bar

    # ssh
    ssh ${CONN_PARAM}
}

log_tomcat() {
    tail -f -n 500 "${TOMCAT_DIR}/logs/catalina.out"
}

log_webapp() {
    TODAY=`date +%Y-%m-%d`

    tail -f -n 500 "${SITE_DIR}/${PARAM1}/application/logs/log-${TODAY}.php"
}

log_cron() {
    find ${LOGS_DIR}/** -type f -mtime +10 | xargs gzip
    find ${LOGS_DIR}/** -type f -mtime +20 | xargs rm -rf
}

service_update() {
    ${SUDO} yum update -y
}

service_install() {
    ${SUDO} yum install -y $1
}

service_remove() {
    ${SUDO} yum remove -y $1
}

service_ctl() {
    if [ "${OS_TYPE}" == "el7" ]; then
        ${SUDO} systemctl $2 $1.service

        if [ "$3" == "on" ]; then
            ${SUDO} systemctl enable $1.service
        fi
        if [ "$3" == "off" ]; then
            ${SUDO} systemctl disable $1.service
        fi
    else
        ${SUDO} service $1 $2

        if [ "$3" == "on" ]; then
            ${SUDO} chkconfig $1 on
        fi
        if [ "$3" == "off" ]; then
            ${SUDO} chkconfig $1 off
        fi
    fi
}

httpd_graceful() {
    echo_ "httpd graceful..."

    if [ "${OS_TYPE}" == "el7" ]; then
        service_ctl httpd restart
    else
        service_ctl httpd graceful
    fi
}

httpd_restart() {
    echo_ "httpd restart..."

    service_ctl httpd restart
}

tomcat_stop() {
    if [ "${HAS_WAR}" == "TRUE" ]; then
        status=`ps -ef | grep catalina | grep java | grep -v grep | wc -l | awk '{print $1}'`
        if [ ${status} -ge 1 ]; then
            echo_ "tomcat stop..."
            ${TOMCAT_DIR}/bin/shutdown.sh
            sleep 3
        fi
    fi
}

tomcat_start() {
    if [ "${HAS_WAR}" == "TRUE" ]; then
        status=`ps -ef | grep catalina | grep java | grep -v grep | wc -l | awk '{print $1}'`
        count=0
        while [ ${status} -ge 1 ]; do
            echo_ "wait tomcat..."
            sleep 3

            if [ ${count} -ge 5 ]; then
                pid=`ps -ef | grep catalina | grep java | grep -v grep | awk '{print $2}'`
                kill -9 ${pid}
                echo_ "tomcat (${pid}) was killed."
            fi

            sleep 2
            status=`ps -ef | grep catalina | grep java | grep -v grep | wc -l | awk '{print $1}'`
            count=`expr ${count} + 1`
        done

        echo_ "tomcat start..."
        ${TOMCAT_DIR}/bin/startup.sh
    fi
}

process_stop_all() {
    if [ "${HAS_JAR}" == "TRUE" ]; then
        PID=`ps -ef | grep "[j]ava" | grep "[-]jar" | awk '{print $2}'`
        if [ "${PID}" != "" ]; then
            kill -9 ${PID}
            echo_ "killed (${PID})"
        fi
    fi
}

process_stop() {
    PID=`ps -ef | grep "[${ARTIFACT_ID:0:1}]""${ARTIFACT_ID:1}" | grep "[-]jar" | awk '{print $2}'`
    if [ "${PID}" != "" ]; then
        kill -9 ${PID}
        echo_ "killed (${PID})"
    fi
}

process_start() {
    java -jar ${JAR_OPTS} ${DEPLOY_PATH}/${ARTIFACT_ID}.${PACKAGING} >> /dev/null &

    PID=`ps -ef | grep "[${ARTIFACT_ID:0:1}]""${ARTIFACT_ID:1}" | grep "[-]jar" | awk '{print $2}'`
    if [ "${PID}" != "" ]; then
        echo_ "startup (${PID})"
    fi
}

add_source() {
    if [ "$1" == "" ]; then
        return
    fi

    touch $1

    BASHRC="${HOME}/.bashrc"
    touch ${BASHRC}

    VAL="source $1"

    HAS_KEY="false"

    while read LINE
    do
        if [ "${LINE}" == "${VAL}" ]; then
            HAS_KEY="true"
        fi
    done < ${BASHRC}

    if [ "${HAS_KEY}" == "false" ]; then
        echo "${VAL}" >> ${BASHRC}
    fi
}

add_path() {
    if [ "$1" == "" ]; then
        return
    fi

    TARGET="${HOME}/.toast_base"

    add_source ${TARGET}

    echo "export PATH=\"\$PATH:$1\"" >> ${TARGET}

    source ${TARGET}
}

mod_env() {
    if [ "$1" == "" ]; then
        return
    fi

    TARGET="${HOME}/.toast_base"

    add_source ${TARGET}

    mod_conf ${TARGET} "export $1" "$2"

    source ${TARGET}
}

mod_conf() {
    TARGET=$1

    if [ ! -f ${TARGET} ]; then
        return
    fi

    if [ "$2" == "" ]; then
        return
    fi

    KEY=$2
    VAL=$3

    HAS_KEY="false"

    while read LINE
    do
        KEY1=$(echo ${LINE} | cut -d "=" -f 1)

        if [ "${KEY1}" == "${KEY}" ]; then
            HAS_KEY="true"
        fi
    done < ${TARGET}

    if [ "${HAS_KEY}" == "true" ]; then
        TEMP_FILE="${TEMP_DIR}/toast-replace.tmp"

        sed "s/${KEY}\=/\#${KEY}\=/g" ${TARGET} > ${TEMP_FILE}
        copy ${TEMP_FILE} ${TARGET} 600
    fi

    echo "${KEY}=\"${VAL}\"" >> ${TARGET}
}

mod() {
    if [ "$1" == "" ]; then
        return
    fi

    if [ "${USER}" != "" ]; then
        ${SUDO} chown ${USER}.${USER} $1
    fi

    if [ "$2" != "" ]; then
        ${SUDO} chmod $2 $1
    fi
}

copy() {
    if [ "$1" == "" ]; then
        return
    fi
    if [ "$2" == "" ]; then
        return
    fi

    ${SUDO} cp -rf $1 $2

    mod $2 $3
}

new_file() {
    if [ "$1" == "" ]; then
        return
    fi

    ${SUDO} rm -rf $1
    ${SUDO} touch $1

    mod $1 $2
}

make_dir() {
    if [ "$1" == "" ]; then
        return
    fi

    if [ ! -d $1 ] && [ ! -f $1 ]; then
        mkdir $1
    fi

    if [ ! -d $1 ] && [ ! -f $1 ]; then
        ${SUDO} mkdir $1
    fi

    mod $1 $2
}

not_darwin() {
    if [ "${OS_TYPE}" == "Darwin" ]; then
        warning "Not supported OS - ${OS_TYPE}"
        exit 1
    fi
}

echo_bar() {
    echo_ "================================================================================"
}

echo_toast() {
    echo_bar
    echo_ "                              _  _          _                  _        "
    echo_ "      _   _  __ _ _ __   ___ | |(_) __ _   | |_ ___   __ _ ___| |_      "
    echo_ "     | | | |/ _\` | '_ \ / _ \| || |/ _\` |  | __/ _ \ / _\` / __| __|  "
    echo_ "     | |_| | (_| | | | | (_) | || | (_| |  | || (_) | (_| \__ \ |_      "
    echo_ "      \__, |\__,_|_| |_|\___/|_|/ |\__,_|   \__\___/ \__,_|___/\__|     "
    echo_ "      |___/                   |__/                                      "
    echo_ "                                                         by nalbam      "
    echo_bar
}

################################################################################

JAR_OPTS=""

toast

# done
success "done."
