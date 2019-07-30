# Installation

## Manual installation of ioBroker.nodejs on Debian based Linux (Raspbian, Ubuntu, ...)

### Prerequisites

#### [Node.js](http://nodejs.org) (Node.js version >= 0.8, including npm)

* ```wget http://ccu.io.mainskater.de/nodejs_0.10.22-1_armhf.deb ; sudo dpkg -i nodejs_0.10.22-1_armhf.deb ; rm nodejs_0.10.22-1_armhf.deb```

Sometimes node.js has not installed the soft link. If you see outputs with ```/usr/bin/nodejs -v```, following can help:
```ln -s /usr/bin/nodejs /usr/bin/node```

### Download and Install

* Create and change to the directory under which you want to install ioBroker.

    ```sudo mkdir /opt/iobroker ; sudo chown $USER.$USER /opt/iobroker ; cd /opt/iobroker```
* Install

    ```sudo -H npm install iobroker --production --loglevel error --unsafe-perm```

* Load available adapter information

    ```iobroker update```

# Start ioBroker controller

* run ```iobroker start``` to start the ioBroker controller in the background
* watch the logfile ```tail -f log/iobroker.log```

or

* run ```node node_modules/iobroker.js-controller/controller.js``` to start the ioBroker controller in foreground and watch the log on console


## Admin UI

The admin adapter starts a webserver that hosts the Admin UI. Default port is 8081, so just open http://&lt;iobroker&gt;:8081/

# Install more adapters

After Installation of an Adapter you should edit it's configuration. Go to the tab "instances" in the Admin UI.
By clicking a adapter instance you can directly enable it by checking the enabled checkbox. Press enter to save or escape
to cancel.
To edit the adapters configuration mark the adapter row and click the pencil icon (lower left).



