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

OS_NAME=`uname`
if [ ${OS_NAME} != "Linux" ]; then
    warning "Not supported OS : ${OS_NAME}"
    exit 1
fi

SUDO=""
if [ "${HOME}" != "/root" ]; then
    SUDO="sudo"
fi

################################################################################

NAME="tomcat"

VERSION="8.0.41"

FILE="apache-tomcat-${VERSION}"

EXT="tar.gz"

TOMCAT_DIR="/data/apps/tomcat8"

# s3://repo.toast.sh/tomcat/apache-tomcat-8.0.41.tar.gz

################################################################################

REPO="$1"

if [ "${REPO}" != "" ]; then
    URL="${REPO}/${NAME}/${FILE}.${EXT}"

    echo_ "download... [${URL}]"

    aws s3 cp ${URL} ./
fi

if [ ! -f ${FILE}.${EXT} ]; then
    warning "Can not download : ${URL}"

    URL="http://repo.toast.sh/${NAME}/${FILE}.${EXT}"

    echo_ "download... [${URL}]"

    wget -q -N ${URL}
fi

if [ ! -f ${FILE}.${EXT} ]; then
    warning "Can not download : ${URL}"
    exit 1
fi

################################################################################

tar xzf ${FILE}.${EXT}

mv apache-tomcat-${VERSION} ${TOMCAT_DIR}

chmod 755 ${TOMCAT_DIR}/bin/*.sh

rm -rf ${TOMCAT_DIR}/webapps/*

echo_ "CATALINA_HOME=${TOMCAT_DIR}"

rm -rf ${FILE}.${EXT}
