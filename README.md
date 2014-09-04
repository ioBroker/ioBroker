# ioBroker

*...domesticate the Internet of Things.*

ioBroker is an integration platform for the [Internet of Things](http://en.wikipedia.org/wiki/Internet_of_Things),
focused on Building Automation, Smart Metering, Ambient Assisted Living, Process Automation, Visualization and
Data Logging. It aims to be a possible replacement for software like f.e. [fhem](http://fhem.de),
[OpenHAB](http://www.openhab.org/) or [the thing system](http://thethingsystem.com/) by the end of 2014. ioBroker will
be the successor of [CCU.IO](http://ccu.io), a project quite popular in the
[german HomeMatic community](http://homematic-forum.de/forum/).

## Concept

ioBroker is not just an application, it's more of a a concept, a database schema, and offers a very easy way for systems
to interoperate. ioBroker defines some common rules for a pair of databases used to exchange data and publish events
between different systems.

![architecture](img/architecture.png)

#### Databases

ioBroker uses [Redis](http://redis.io/) and [CouchDB](http://couchdb.apache.org/). Redis is an in-memory key-value data
store and also a message broker with publish/subscribe pattern. It's used to maintain and publish all states of
connected systems. CouchDB is used to store rarely changing and larger data, like metadata of systems and things,
configurations or any additional files.

#### Adapters

Systems are attached to ioBrokers databases via so called adapters, technically processes running anywhere
in the network and connecting all kinds of systems to ioBrokers databases. A connection to ioBrokers databases can be
implemented in nearly any programming language on nearly any platform and an adapter can run on any host that is able to
reach the databases via ip networking.

A library module for fast and comfortable adapter development exists for Javascript/Node.js until now. Libraries for
adapter development in other languages are planned (python, java, perl, ...).



| adapter    	                                                                                            | description                                                                     	                                                                                                                                                                                                        | status 	|
|-------------------------------------------------------------------------------------------------------    |----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------   |--------	|
|                                                                                                           | **system services**                                                                                                                                                                                                                                                                       |           |
| [admin](https://github.com/iobroker/ioBroker.nodejs/blob/master/adapter/admin/README.md)      	        | admin user interface                                                            	                                                                                                                                                                                                        | alpha  	|
| [history](https://github.com/iobroker/ioBroker.nodejs/blob/master/adapter//history/README.md)    	        | state history                                                                   	                                                                                                                                                                                                        | alpha  	|
| [legacy](https://github.com/iobroker/ioBroker.nodejs/blob/master/adapter//legacy/README.md)     	        | [CCU.IO](http://ccu.io)-compatible Webserver                                                     	                                                                                                                                                                                        | alpha  	|
| [socketio](https://github.com/iobroker/ioBroker.socketio)   	                                            | [Socket.io](http://socket.io) Server                                                            	                                                                                                                                                                                        | planned   |
| [web](https://github.com/iobroker/ioBroker.nodejs/blob/master/web/README.md)        	                    | [Express](http://expressjs.com/) based webserver                                           	                                                                                                                                                                                            | alpha     |
| [websocket](https://github.com/iobroker/ioBroker.nodejs/blob/master/web/README.md)        	            | [Express](http://expressjs.com/) and [Socket.io](http://socket.io) based webserver                                           	                                                                                                                                                                                | alpha     |
|           	                                                                                            |                                                                                	                                                                                                                                                                                                        |        	|
|                                                                                                           | **automation**                                                                                                                                                                                                                                                                            |           |
| [logic](https://github.com/smiling-Jack/ioBroker.logic/blob/master/README.md) 	                        | Graphical Javascript IDE (former: [ScriptGUI](https://github.com/smiling-Jack/CCU-IO.ScriptGUI))                                                     	                                                                                                                                    | planned   |
| [javascript](https://github.com/iobroker/ioBroker.nodejs/blob/master/javascript/README.md) 	            | Javascript script engine. Use Javascripts/Node.js asynchronous programming with comfortable methods to subscribe to events and schedule events with sophisticated scheduling-features.                                                      	                                            | **beta**  |
| [virtual](https://github.com/iobroker/ioBroker.nodejs/blob/master/adapter/virtual/README.md)      	    | Map objects and states into other namespaces and apply basic rules on the mappings (average, sum, min, max, offset, factor, ...)                                              	                                                                                                        | planned   |
| [scenes](https://github.com/iobroker/ioBroker.scenes/blob/master/adapter/scenes/README.md)      	        | Create and sequence scenes                                              	                                                                                                                                                                                                                | planned   |
| [python](https://github.com/iobroker/ioBroker.nodejs/blob/master/adapter/javascript/README.md) 	        | Python script engine.                                                      	                                                                                                                                                                                                            | planned   |
|           	                                                                                            |                                                                                	                                                                                                                                                                                                        |        	|
|                                                                                                           | **user interfaces**                                                                                                                                                                                                                                                                       |           |
| [mobile](https://github.com/iobroker/ioBroker.mobile)        	                                            | [jQuery Mobile](http://jquerymobile.com/) based User Interface (former [yahui](https://github.com/hobbyquaker/yahui))                                             	                                                                                                                    | alpha     |
| [vis](https://github.com/iobroker/ioBroker.vis)        	                                                | Template based HTML5 User Interface (former [DashUI](https://github.com/hobbyquaker/DashUI))                                              	                                                                                                                                            | planned 	|
|           	                                                                                            |                                                                                	                                                                                                                                                                                                        |        	|
|                                                                                                           | **home automation**                                                                                                                                                                                                                                                                       |           |
| [cul](https://github.com/hobbyquaker/ioBroker.cul)                                                        | Different RF Devices ([FS20](http://www.elv.de/fs20-funkschaltsystem.html), [Max](http://www.eq-3.de/max-heizungssteuerung.html), FHT, HMS, ...) via [CUL](http://busware.de/tiki-index.php?page=CUL)/[COC](http://busware.de/tiki-index.php?page=COC) and [culfw](http://culfw.de)       | alpha  	|
| [dmx](https://github.com/iobroker/ioBroker.artnet)                                                        | Control [DMX](http://en.wikipedia.org/wiki/DMX512) devices via [Art-Net](http://en.wikipedia.org/wiki/Art-Net)                                                                                                                                                                            | alpha  	|
| [hm-rpc](https://github.com/iobroker/ioBroker.hm-rpc)             	                                    | [Homematic](http://www.homematic.com/) XML-RPC                                                            	                                                                                                                                                                            | **beta**  |
| [hm-rega](https://github.com/iobroker/ioBroker.hm-rega)           	                                    | Homematic [CCU](http://www.eq-3.de/produkt-detail-zentralen-und-gateways/items/homematic-zentrale-ccu-2.html)                                                                                                                                                                             | **beta**  |
| [hue](https://github.com/iobroker/ioBroker.hue)        	                                                | [Philips Hue](http://www.meethue.com) LED bulbs and stripes, Smartlink capable LivingColors and LivingWhites 	                                                                                                                                                                            | **beta**  |
| [homepilot](https://github.com/GermanBluefox/ioBroker.homepilot)                                          | [Rademacher Homepilot](http://homepilot.rademacher.de/)	                                                                                                                                                                                                                                | planned   |
| [knx](https://github.com/smiling-Jack/ioBroker.knx)                                                       | [KNX](http://www.knx.org/)                                                                                                                                                                                                                                                                | planned   |
| [z-wave](https://github.com/GermanBluefox/ioBroker.z-wave)                                                | [Z-Wave](http://www.z-wave.com/)                                                                                                                                                                                                                                                          | planned   |
|           	                                                                                            |                                                                                	                                                                                                                                                                                                        |        	|
|                                                                                                           | **home entertainment**                                                                                                                                                                                                                                                                    |           |
| [sonos](https://github.com/ioBroker/ioBroker.sonos)                                                  | [Sonos](http://www.sonos.com/)                                                                                                                                                                                                                                                                 | planned   |
| [mpd](https://github.com/iobroker/ioBroker.mpd)                                                           | [mpd](http://www.musicpd.org/)                                                                                                                                                                                                                                                            | planned   |
| [lirc](https://github.com/iobroker/ioBroker.lirc)                                                         | [LIRC](http://www.lirc.org/)                                                                                                                                                                                                                                                              | planned   |
|           	                                                                                            | ...several TVs and AV Receivers (Pioneer, Onkyo, Yamaha, Samsung, Sony)                                                                         	                                                                                                                                        | planned   |
|           	                                                                                            |                                                                                	                                                                                                                                                                                                        |        	|
|                                                                                                           | **generic protocols**                                                                                                                                                                                                                                                                     |           |
| [telnet](https://github.com/iobroker/ioBroker.telnet)                                                     |                                                                                                                                                                                                                                                                                           | planned   |
| [rest](https://github.com/iobroker/ioBroker.rest)   	                                                    | [REST](http://de.wikipedia.org/wiki/Representational_State_Transfer) compliant API                                                            	                                                                                                                                        | planned   |
| [xmpp](https://github.com/GermanBluefox/ioBroker.xmpp)                                                    | [XMPP](http://en.wikipedia.org/wiki/XMPP)                                                                                                                                                                                                                                                 | planned   |
| [mqtt](https://github.com/GermanBluefox/ioBroker.mqtt)                                                    | [MQTT](http://mqtt.org/)                                                                                                                                                                                                                                                                  | planned   |
|           	                                                                                            |                                                                                	                                                                                                                                                                                                        |        	|
|                                                                                                           | **smart metering**                                                                                                                                                                                                                                                                        |           |
| [b-control-em](https://github.com/hobbyquaker/iobroker.b-control-em)                                      | Smart Metering with [B-Control Energy Manager](http://www.b-control.com/fileadmin/Webdata/b-control/Uploads/Energiemanagement_PDF/EM300_Datenblatt_rev_100.pdf)  	                                                                                                                        | planned   |
|           	                                                                                            |                                                                                	                                                                                                                                                                                                        |        	|
|                                                                                                           | **external software**                                                                                                                                                                                                                                                                     |           |
| [graphite](https://github.com/iobroker/ioBroker.nodejs/blob/master/history/README.md)                     | Manage huge amounts of history data and draw charts with [Graphite](http://graphite.wikidot.com/)                                                                                                                                                                                         | planned   |
| [nagios](https://github.com/ioBroker/ioBroker.nagios)                                                     | Offer selected objects as [Nagios](http://www.nagios.org/)/[Icinga](https://www.icinga.org/) checks with optional performance data, include nagios hosts as ioBroker objects                                                                                                              | planned   |
|           	                                                                                            |                                                                                	                                                                                                                                                                                                        |        	|
|                                                                                                           | **web services**                                                                                                                                                                                                                                                                          |           |
| [email](https://github.com/iobroker/ioBroker.email)        	                                            | send emails                                                	                                                                                                                                                                                                                            | planned 	|
| [imap](https://github.com/iobroker/ioBroker.imap)        	                                                | Control ioBroker with emails in clear text over imap protocoll                                                	                                                                                                                                                                        | planned 	|
| [dwd](https://github.com/iobroker/ioBroker.dwd)        	                                                | fetch weather warnings from [DWD](http://www.dwd.de)                                                	                                                                                                                                                                                    | planned 	|
| [geofency](https://github.com/iobroker/ioBroker.geofency)                                                 | Receive [Geofency](http://www.geofency.com/) webhooks                                                        	                                                                                                                                                                            | planned   |
| [ical](https://github.com/ioBroker/ioBroker.ical)                                                         | Fetch iCal/VCALENDAR events                                                                                                                                                                                                                                                               | planned   |
| [pushover](https://github.com/iobroker/ioBroker.pushover)                                                 | Send [Pushover](https://pushover.net/) notifications                                                    	                                                                                                                                                                                | planned   |
| [pushbullet](https://github.com/iobroker/ioBroker.pushbullet)                                             | Send [Pushbullet](https://www.pushbullet.com/) notifications                                                    	                                                                                                                                                                        | planned   |
| [yr](https://github.com/iobroker/ioBroker.yr)         	                                                | fetch 48h weather forecasts from [yr.no](http://yr.no)                                          	                                                                                                                                                                                        | **beta**  |
|           	                                                                                            |                                                                                	                                                                                                                                                                                                        |        	|
|                                                                                                           | **other**                                                                                                                                                                                                                                                                                 |           |
| [text-commands](https://github.com/iobroker/ioBroker.text-commands)  	                                    | Control ioBroker with commands in clear text, like "Switch on the light in the living room". Used by other adapters, like imap or voice control                                               	                                                                                        | planned 	|
| [text2speech](https://github.com/iobroker/ioBroker.text2speech)                                           | Text to speech adapter                                                	                                                                                                                                                                                                                | planned 	|




#### Security

ioBroker is designed to be accessed by trusted adapters inside trusted networks. This means that usually it is not a
good idea to expose the ioBroker databases, adapters or any smarthome devices directly to the internet or, in general,
to an environment where untrusted clients can directly access these network services. Adapters that offer services
supposed to be exposed to the internet should be handled with care, for example with additional security measures
like VPN, VLAN and reverse proxys.



## Getting Started

#### Operating System and Hardware

[ioBroker.nodejs](https://github.com/iobroker/ioBroker.nodejs/) should run on any hardware and os that runs
[Node.js](http://nodejs.org/) (ARM, x86, Windows, Linux, OSX). Binary builds for CouchDB and Redis are also available
for the ARM and x86 under Windows, Linux and OSX. ioBroker spawns a new Node.js-Process for every adapter instance, so
RAM becomes is a limiting factor. A single adapters memory fingerprint is roundabout 10-60MB. Since CouchDB can create
quite a lot of load a dual core system is beneficial.

We recommend x86 based or ARM based systems like [BananaPi](http://www.bananapi.org/p/product.html) or
[Cubietruck](http://www.exp-tech.de/Mainboards/ARM/Cubietruck.html) using Debian based Linux as operating system.

#### Installation and first steps

* automated installation packages for windows and linux coming soon
* [ioBroker.nodejs manual install](https://github.com/iobroker/ioBroker.nodejs/blob/master/README.md)

#### Community support

* get help in the [ioBroker Forums](http://forum.iobroker.org) (english, german and russian language)


## Docs for (adapter-)developers

* [Core Concepts and Database Schema](doc/SCHEMA.md)
* [Example Javascript/Node.js Adapter](https://github.com/ioBroker/ioBroker.nodejs/blob/master/adapter/example/example.js)
* [ioBroker styleguides](doc/STYLE.md)
* [ioBroker.nodejs Changelog](https://github.com/ioBroker/ioBroker.nodejs/blob/master/CHANGELOG.md)
* [ioBroker.nodejs Roadmap](https://github.com/ioBroker/ioBroker.nodejs/blob/master/ROADMAP.md)
* Direct access to all ioBroker Objects is possible via the CouchDB-Webinterface "Futon": ```http://<couch>:5984/_utils/```
* Use the view selector on the upper right in CouchDB to browse ioBroker objects
* you can use ```redis_cli``` and issue the command ```PSUBSCRIBE *``` to watch all stateChange Events on the Console


## License

The MIT License (MIT)

Copyright (c) 2014 hobbyquaker, bluefox

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.


