#!/bin/bash
### BEGIN INIT INFO
# Provides:        tomcat
# Required-Start:  $network
# Required-Stop:   $network
# Default-Start:   2 3 4 5
# Default-Stop:    0 1 6
# Short-Description: Start/Stop Tomcat server
### END INIT INFO

PATH=/sbin:/bin:/usr/sbin:/usr/bin

export JAVA_HOME="/usr/local/java"

start() {
    /data/apps/tomcat8/bin/startup.sh
}

stop() {
    /data/apps/tomcat8/bin/shutdown.sh
}

case $1 in
    start|stop)
        $1
        ;;
    restart)
        stop
        start
        ;;
    *)
        echo "Run as $0 <start|stop|restart>"
        exit 1
        ;;
esac