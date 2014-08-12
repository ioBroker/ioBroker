# Installation

## Manual installation of ioBroker.nodejs on Debian based Linux (Raspbian, Ubuntu, ...)

### Prerequisites

#### [Node.js](http://nodejs.org) (Node.js version >= 0.8, including npm)

* ```wget http://ccu.io.mainskater.de/nodejs_0.10.22-1_armhf.deb ; sudo dpkg -i nodejs_0.10.22-1_armhf.deb ; rm nodejs_0.10.22-1_armhf.deb```

#### Install [Redis](http://redis.io/)

* ```sudo apt-get install redis-server```

#### Install and configure [CouchDB](http://couchdb.apache.org/)

* ```sudo apt-get install couchdb```
* open the file /etc/couchdb/local.ini and replace the line ```;bind_address = 127.0.0.1``` by ```bind_address = 0.0.0.0``` (make sure to remove the semicolon at the beginning of the line)
* ```sudo /etc/init.d/couchdb restart```


### Download and Install

* Create and change to the directory under which you want to install ioBroker.

    ```sudo mkdir /opt/iobroker ; sudo chown $USER.$USER /opt/iobroker ; cd /opt/iobroker```
* Clone the repository

    ```git clone https://github.com/ioBroker/ioBroker.nodejs /opt/iobroker/```
* Install Node dependencies

    ```npm install --production```
* Grant execute rights

    ```chmod +x iobroker```
* Do initial database setup

    ```./iobroker setup```

    (if your CouchDB and/or Redis is not running on localhost you can supply optional arguments --couch &lt;host&gt; --redis &lt;host&gt;)

* Load available adapter information

    ```./iobroker update```

# Install admin adapter

This adapter is needed to do basic system administration

*   ```./iobroker add admin --enabled```

# Start ioBroker controller

* run ```./iobroker start``` to start the ioBroker controller in the background
* watch the logfile ```tail -f log/iobroker.log```

or

* run ```node controller.js``` to start the ioBroker controller in foreground and watch the log on console


## Admin UI

The admin adapter starts a webserver that hosts the Admin UI. Default port is 8080, so just open http://&lt;iobroker&gt;:8080/


## Access Objects

Direct access to all ioBroker Objects is possible via the CouchDB-Webinterface "Futon": http://&lt;couch&gt;:5984/_utils/

## See Events

you can use ```redis_cli``` and issue the command ```PSUBSCRIBE *``` to watch all stateChange Events on the Console


# Install more adapters

* ```./iobroker add <adapter-name>```
* ```./iobroker add <adapter-url>``` (todo)

After Installation of an Adapter you should edit it's configuration. Go to the tab "instances" in the Admin UI.
By clicking a adapter instance you can directly enable it by checking the enabled checkbox. Press enter to save or escape
to cancel.
To edit the adapters configuration mark the adapter row and click the pencil icon (lower left).



