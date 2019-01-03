#!/bin/bash
### BEGIN INIT INFO
# Provides:          iobroker.sh
# Required-Start:    $network $local_fs $remote_fs
# Required-Stop::    $network $local_fs $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts ioBroker
# Description:       starts ioBroker
### END INIT INFO
(( EUID )) && echo .You need to have root privileges.. && exit 1
PIDF=@@PATH@@lib/iobroker.pid
IOBROKERCMD=@@PATH@@iobroker.js
RETVAL=0
IOBROKERUSER=@@user
HOMEDIR=`getent passwd ${IOBROKERUSER} | cut -d\: -f 6`
NVM_DIR="${HOMEDIR}/.nvm"
if [ -d "${NVM_DIR}" ]; then
            export NVM_DIR
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
            NODECMD=`nvm which node`
            echo "NVM detected."
            echo "Use ${NODECMD} to start IOBroker."
else
            NODECMD=@@node
fi

start() {
            export IOBROKER_HOME=@@HOME@@
            echo -n "Starting ioBroker"
            sudo -u ${IOBROKERUSER} $NODECMD $IOBROKERCMD start
            RETVAL=$?
}

stop() {
            echo -n "Stopping ioBroker"
            sudo -u ${IOBROKERUSER} $NODECMD $IOBROKERCMD stop
            RETVAL=$?
}
case "$1" in
    start)
      start
  ;;
    stop)
      stop
  ;;
    restart)
      stop
      start
  ;;
    *)
      echo "Usage: iobroker {start|stop|restart}"
      exit 1
  ;;
esac
exit $RETVAL
