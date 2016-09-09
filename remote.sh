#!/bin/bash

############################################################

function usage() {
  echo "Usage: $0 {user} {host} {port:22}"
}

############################################################

BASEDIR=$(dirname $0)
cd ${BASEDIR}

USER=${1}
HOST=${2}
PORT=${3}

CMD=${4}
SUB=${5}

PARAM1=${6}
PARAM2=${7}
PARAM3=${8}
PARAM4=${9}
PARAM5=${10}

if [ "${HOST}" == "" ]; then
  usage
  exit 1
fi

if [ "${PORT}" == "" ]; then
  PORT=22
fi

COMMAND="~/toaster/toast.sh ${CMD} ${SUB} ${PARAM1} ${PARAM2} ${PARAM3} ${PARAM4} ${PARAM5}"

ssh -t ${USER}@${HOST} -p ${PORT} "${COMMAND}"

# ~/toaster/remote.sh user host port deploy fleet
# ~/toaster/remote.sh user host port deploy project com.yanolja yanolja.deploy 0.0.2 php deploy.yanolja.com