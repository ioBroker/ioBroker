# ioBroker

*Automate your life!*

See [ioBroker wiki](https://github.com/ioBroker/ioBroker/wiki/Home-(English)) for more information


[ioBroker website](http://iobroker.net)
[Bug tracking JIRA](http://iobroker.net:8000)
[Demo admin](http://iobroker.net:8081)
[Demo VIS](https://iobroker.net:8080)


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

See actual list of adapters on [iobroker.net](http://iobroker.net)


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

Copyright (c) 2014-2016 bluefox

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


