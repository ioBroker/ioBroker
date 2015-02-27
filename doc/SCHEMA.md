
# Core Concept

There are two fundamentally different data-types in ioBroker. So called **states** and **objects**.

Objects represent rarely changing and larger data, like meta-data of your systems devices, configurations and additional
files. Every Object has to have an attribute "type". See below for more information what object types are available and which
mandatory attributes a object of a specific type needs. Functions like setObject, getObject, ... are provided to you by
the adapter module.

States represent often changing data in your system, like f.e. if a lamp is on or off, if a motion detector detected
some motion, the temperature of your living room or if the button of a remotecontrol is pressed. Contrary to objects
states can be used to trigger actions and states can create history data. To work with states there are several functions
in the adapter module like setState, getState and so on.

For every state there also has to exist a corresponding object with type=state.

# Database Schema

## IDs

a string with a maximum length of 240 bytes, hierarchically structured, levels separated by dots.


### Namespaces

* system.
* system.host.        - Controller processes
* system.config.      - System settings, like default language
* system.meta.        - System meta data
* system.user.
* system.group.
* system.translations. - system wide translation objects
* system.adapter.&lt;adapter-name&gt; - default config of an adapter
* &lt;adapter-name&gt; - object holding attachments that are accessible via http://&lt;couch&gt;:5984/iobroker/&lt;adapter-name&gt;/path
* &lt;adapter-name&gt;.meta. - common meta-data used by all instances of this adapter
* &lt;adapter-name&gt;.&lt;instance-number&gt;. - An adapters instance namespace
* enum.               - Enumerations
* history.            - History Data
* scripts.            - Script Engine Scripts
* scripts.js.         - javascript Script Engine Scripts
* scripts.py.         - python Script Engine Scripts

#### Namespace system.config.
<pre>
{
    _id:   id,
    type: 'config',
    common: {
        language:     'en',         // Default language for adapters. Adapters can use different values.
        tempUnit:     '°C',         // Default temperature units.
        currency:     '€',          // Default currency sign.
        dateFormat:   'DD.MM.YYYY'  // Default date format.
        isFloatComma: true,         // Default float divider ('.' - false, ',' - true)
        "activeRepo": "online1",    // active repository 
        "listRepo": {               // list of possible repositories
            "default": "conf/sources-dist.json",
            "online1": "https://raw.githubusercontent.com/ioBroker/ioBroker.nodejs/master/conf/sources-dist.json"
        }
    }
}
</pre>

#### Namespace system.host.&lt;hostname&gt;
<pre>
{
    _id:   id,
    type: 'host',
    common: {
        name:       id,
        process:    title,           // iobroker.ctrl
        version:    version,         // Vx.xx.xx
        platform:   'javascript/Node.js',
        cmd:        process.argv[0] + ' ' + process.execArgv.join(' ') + ' ' + process.argv.slice(1).join(' '),
        hostname:   hostname,
        address:    ipArr,
        defaultIP:  ???
    },
    native: {
        process: {
            title:      process.title,
            pid:        process.pid,
            versions:   process.versions,
            env:        process.env
        },
        os: {
            hostname:   hostname,
            type:       os.type(),
            platform:   os.platform(),
            arch:       os.arch(),
            release:    os.release(),
            uptime:     os.uptime(),
            endianness: os.endianness(),
            tmpdir:     os.tmpdir()
        },
        hardware: {
            cpus:       os.cpus(),
            totalmem:   os.totalmem(),
            networkInterfaces: os.networkInterfaces()
        }
    }
};
</pre>


## States

getState method and stateChange event delivers an object with all attributes except expire

for "setState" method everything except "val" is optional, "from" is set automatically by the "setState" method. "ack" defaults to false, "ts" and "lc" are set as expected

attributes for getState/stateChange/setState object:

* val    - the actual value - can be any type that is JSON-encodable
* ack    - a boolean flag indicating if the target system has acknowledged the value
* ts     - a unix timestamp indicating the last update of the state
* lc     - a unix timestamp indicating the last change of the state's actual value
* from   - adapter instance that did the "setState"
* expire - a integer value that can be used to set states that expire after a given number of seconds. Can be used ony with setValue. After the value expires, it disappears from redisDB.


Every *state* has to be represented by an object of the type state containing Meta-Data for the state. see below.

## Objects

### Mandatory attributes

Following attributes have to exist in every object:

* _id
* type        - see below for possible values
* common      - an object containing iobroker specific abstraction properties
* native      - an object containing congruent properties of the target system

### Optional attributes

* parent   - ID of parent object (see below)
* children - Array of children IDs
* common.name - the name of the object

### Tree structure

Objects can have a *parent* attribute containing the *id* of their parent to build a tree structure. This should be
limited to 3 levels (except for objects of type enum). An object referenced as a parent has to have a children property
with an array of children IDs - if parent is used children is mandatory and vice versa.

### Object types

* state    - parent should be of type channel, device, instance or host
* channel  - object to group one or more states. parent should be device
* device   - object to group one or more channels or state. should have no parent.
* enum     - objects holding a array in common.members that points to states, channels, devices or files. enums can have a parent enum (tree-structure possible)
* host     - a host that runs a controller process
* adapter  - the default config of an adapter. presence also indicates that the adapter is successfully installed. (suggestion: should have an attribute holding an array of the hosts where it is installed)
* instance - instance of adapter. Parent has to be of type adapter
* meta     - rarely changing meta information that a adapter or his instances needs
* config   - configurations
* script
* user
* group


### Attributes for specific object types

#### state

attributes:

* common.type   (optional - (default is mixed==any type) (possible values: number, string, boolean, array, object, mixed)
* common.min    (optional)
* common.max    (optional)
* common.unit   (optional)
* common.def    (optional - the default value)
* common.desc   (optional, string)
* common.read   (boolean, mandatory) - true if state is readable
* common.write  (boolean, mandatory) - true if state is writeable
* common.role   (string,  mandatory) - role of the state (used in user interfaces to indicate which widget to choose, see below)
* common.states (optional) attribut of type number with array of possible states
* common.workingID (string, optional) - if this state has helper state WORKING. Here must be written the full name or just the last part if the first parts are the same with actual. Used for HM.LEVEL and normally has value "WORKING"


##### state common.history

History function needs the history adapter

fifo length is reduced to min when max is hit. set to null or leave undefined to use defaults

for a list of transports see history adapter README

* common.history (optional)
* common.history.changesOnly (optional, boolean, if true only value changes are logged)
* common.history.fifo (optional, high speed history storage)
* common.history.fifo.enabled (boolean)
* common.history.fifo.min (integer, min fifo length)
* common.history.fifo.max (integer, max fifo length)
* common.history.fifo.transports (array of strings, log-transports data should be sent to after leaving the fifo)
* common.history.direct.enabled (boolean)
* common.history.direct.transports (array of strings, log-transports data should be sent on change)

* common.role (indicates how this state should be represented in user interfaces)

##### state common.role

possible values:

* text (common.type = string)
* text.url (common.type = string) state val contains a url for usage in an anchor, iframe or img
* html (common.type = string)
* json (common.type = string)
* list (common.type = array)
* list.horizontal
* ...

* value             (common.type=number, common.write=false)
* value.temperature (common.type=number, common.write=false, common.unit='°C' or '°F' or 'K')
* value.humidity    (common.type=number, common.write=false)
* value.brightness  (common.type=number, common.write=false)
* value.min         (common.type=number, common.write=false)
* value.max         (common.type=number, common.write=false)
* value.default     (common.type=number, common.write=false)
* value.battery     (common.type=number, common.write=false) - battery level
* ...
* value.power.consumption or power.consumption ?

* direction   (common.type=number or string, indicates up/down, left/right, 4-way switches, wind-direction, ... )

* button (common.type=boolean)
* button.long
* button.stop
* button.play
* button.next
* button.prev
* button.pause
* button.forward
* button.reverse
* button.fastforward
* button.fastreverse
* ...

* indicator             (common.type=boolean)
* indicator.working     (common.type=boolean, indicates that something the target systems is doing changes on the parent channel)
* indicator.reachable
* indicator.connected
* indicator.maintenance (common.type=boolean, indicates system warnings/errors, alarms, service messages, battery empty or stuff like that)
* indicator.maintenance.lowbat (description texts for stuff like that can be stored in adapter- or system-metadata)
* indicator.maintenance.unreach
* indicator.maintenance.alarm

* level                 (common.type=number, common.write=true)
* level.dimmer
* level.blind
* level.temperature
* level.color.red
* level.color.green
* level.color.blue
* level.color.hue
* level.color.saturation
* level.color.luminance
* level.color.temperature
* ...
* level.volume          (common.type=number, common.write=true, min=0, max=100)

* switch (common.type=boolean, common.write=true)
* 

* ...
* text.phone_number
* 
* adapter.messagebox     (common.type=object, common.write=true) used to send messages to email, pushover and other adapters
* adapter.wakeup         (common.type=boolean, common.write=true) wake up adapter from suspended mode
* adapter.run            (common.type=boolean, common.write=true) start or stop adapter, that supoprt it

#### channel

##### channel common.role - (HQ: Is it mandatory? I think no.)

suggestion: the channel-objects common.role should/could imply a set of mandatory and/or optional state-child-objects

possible values:

* info          - Currency or shares rate, fuel prices, post box insertion and stuff like that
* calendar      -
* forecast      - weather forecast

* media         - common media channel
* media.music   - media player, like SONOS, YAMAHA and so on
* media.tv      - TV 
* media.tts     - text to speech

* thermo        - Monitor or control the temperature, humidity and so on
* thermo.heat 
* thermo.cool
*
* blind             - Window blind control

* light
* light.dimmer      - Light dimmer
* light.switch      - Light switch.
* light.color       - Light control with ability of color changing
* light.color.rgb   - Set color in RGB
* light.color.rgbw  - Set color in RGBW
* light.color.hsl   - Set color in Hue/Saturation/Luminance (Hue color light - LivingColors...)
* light.color.hslct - Set color in Hue/Saturation/Luminance or Color Temperature (Hue extended color light)
* light.color.ct    - color temperature K 

* switch            - Some generic switch

* sensor            - E.g. window or door contact, water leak sensor, fire sensor
* sensor.door       - open, close
* sensor.door.lock  - open, close, locked
* sensor.window     - open, close
* sensor.window.3   - open, tilt, close
* sensor.water      - true(alarm), false (no alarm)
* sensor.fire       - true(alarm), false (no alarm)
* sensor.CO2        - true(alarm), false (no alarm)
* 
* alarm             - some alarm

* phone             - fritz box, speedport and so on

* button            - like wall switch or TV remote, where every button is a state like .play, .stop, .pause
* remote            - TV or other remotes with state is string with pressed values, e.g. "PLAY", "STOP", "PAUSE"

* meta              - Information about device
* meta.version      - device version
* meta.config       - configuration from device
* ...


#### Channel descriptions
~~The names of the attributes can be free defined by adapter, except ones written with **bold** font.~~

"W" - common.write=true

"M" - Mandatory

##### Optional states for every channel/device

```javascript
// state-working (optional)
{
   "_id": "adapter.instance.channelName.stateName-working", // e.g. "hm-rpc.0.JEQ0205612:1.WORKING"
   "type": "state",
   "parent": "channel or device",       // e.g. "hm-rpc.0.JEQ0205612:1"
   "common": {
       "name":  "Name of state",        // mandatory, default _id ??
       "def":   false,                  // optional,  default false
       "type":  "boolean",              // optional,  default "boolean"
       "read":  true,                   // mandatory, default true
       "write": false,                  // mandatory, default false
       "min":   false,                  // optional,  default false
       "max":   true,                   // optional,  default true
       "role":  "indicator.working"     // mandatory
       "desc":  ""                      // optional,  default undefined
   }
}
,
// state-direction (optional). The state can have following states: "up"/"down"/""
{
   "_id": "adapter.instance.channelName.stateName-direction", // e.g. "hm-rpc.0.JEQ0205612:1.DIRECTION"
   "type": "state",
   "parent": "channel or device",       // e.g. "hm-rpc.0.JEQ0205612:1"
   "common": {
       "name":  "Name of state",        // mandatory, default _id ??
       "def":   "",                     // optional,  default ""
       "type":  "string",               // optional,  default "string"
       "read":  true,                   // mandatory, default true
       "write": false,                  // mandatory, default false
       "role":  "direction"             // mandatory
       "desc":  ""                      // optional,  default undefined
   }
}
,
// state-maintenance (optional).
{
   "_id": "adapter.instance.channelName.stateName-maintenance", //e.g. "hm-rpc.0.JEQ0205612:1.MAINTENANCE"
   "type": "state",
   "parent": "channel or device",       // e.g. "hm-rpc.0.JEQ0205612:1"
   "common": {
       "name":  'Name of state",        // mandatory, default _id ??
       "def":   false,                  // optional,  default false
       "type":  "boolean",              // optional,  default "boolean"
       "read":  true,                   // mandatory, default true
       "write": false,                  // mandatory, default false
       "min":   false,                  // optional,  default false
       "max":   true,                   // optional,  default true
       "role":  "indicator.maintenance" // mandatory
       "desc":  'Problem description'   // optional,  default undefined
   }
}
,
// state-maintenance-unreach (optional).
{
   "_id": "adapter.instance.channelName.stateName-maintenance-unreach", //e.g. "hm-rpc.0.JEQ0205612:0.UNREACH"
   "type": "state",
   "parent": "channel or device",       // e.g. "hm-rpc.0.JEQ0205612:1"
   "common": {
       "name":  "Name of state",        // mandatory, default _id ??
       "def":   false,                  // optional,  default false
       "type":  "boolean",              // optional,  default "boolean"
       "read":  true,                   // mandatory, default true
       "write": false,                  // mandatory, default false
       "min":   false,                  // optional,  default false
       "max":   true,                   // optional,  default true
       "role":  "indicator.maintenance.unreach" // mandatory
       "desc":  "Device unreachable"    // optional,  default 'Device unreachable'
   }
}
```

##### light.switch - Attributes description
| **Name**      | **common.role**           | **M** | **W** | **common.type** | **Description**
| ------------- |:--------------------------|:-----:|:-----:|-----------------|---
| state         | switch                    |   X   |   X   | boolean         |
| description   | text.description          |       |       |                 |
| mmm           | indicator.maintenance.mmm |       |       |                 | mmm = lowbat or unreach or whatever
```javascript
// SWITCH CHANNEL
{
   "_id": "adapter.instance.channelName", // e.g. "hm-rpc.0.JEQ0205614:1"
   "type": "channel",
   "parent": "device or empty",         // e.g. "hm-rpc.0.JEQ0205614"
   "children": [
       "adapter.instance.channelName.state-switch",              // mandatory
       "adapter.instance.channelName.state-maintenance"          // optional
       "adapter.instance.channelName.state-maintenance-unreach"  // optional
   ],
   "common": {
       "name":  "Name of channel",      // mandatory, default _id ??
       "role":  "light.switch"          // optional   default undefined
       "desc":  ""                      // optional,  default undefined
   }
},
// SWITCH STATES
{
   "_id": "adapter.instance.channelName.state-switch", // e.g. "hm-rpc.0.JEQ0205614:1.STATE"
   "type": "state",
   "parent": "channel or device",       // e.g. "hm-rpc.0.JEQ0205614:1"
   "common": {
       "name":  "Name of state",        // mandatory, default _id ??
       "def":   false,                  // optional,  default false
       "type":  "boolean",              // optional,  default "boolean"
       "read":  true,                   // mandatory, default true
       "write": true,                   // mandatory, default true
       "role":  "switch"                // mandatory
       "desc":  ""                      // optional,  default undefined
   }
}
// see "Optional states for every channel/device" for description of optional states
//            "adapter.instance.channelName.state-maintenance"          // optional
//            "adapter.instance.channelName.state-maintenance-unreach"  // optional

```

##### light.dimmer - Attributes description
```javascript
// DIMMER CHANNEL
{
   "_id": "adapter.instance.channelName", // e.g. "hm-rpc.0.JEQ0205612:1"
   "type": "channel",
   "parent": "device or empty",         // e.g. "hm-rpc.0.JEQ0205612"
    "children": [
       "adapter.instance.channelName.state-level",               // mandatory
       "adapter.instance.channelName.state-working",             // optional
       "adapter.instance.channelName.state-direction",           // optional
       "adapter.instance.channelName.state-maintenance"          // optional
       "adapter.instance.channelName.state-maintenance-unreach"  // optional
    ],
   "common": {
       "name":  "Name of channel",      // mandatory, default _id ??
       "role":  "light.dimmer"          // optional   default undefined
       "desc":  ""                      // optional,  default undefined
   }
},
// DIMMER STATES
{
   "_id": "adapter.instance.channelName.state-level", // e.g. "hm-rpc.0.JEQ0205612:1.LEVEL"
   "type": "state",
   "parent": "channel or device",       // e.g. "hm-rpc.0.JEQ0205612:1"
   "common": {
       "name":  "Name of state",        // mandatory, default _id ??
       "def":   0,                      // optional,  default 0
       "type":  "number",               // optional,  default "number"
       "read":  true,                   // mandatory, default true
       "write": true,                   // mandatory, default true
       "min":   0,                      // optional,  default 0
       "max":   100,                    // optional,  default 100
       "unit":  "%",                    // optional,  default %
       "role":  "level.dimmer"          // mandatory
       "desc":  ""                      // optional,  default undefined
   }
}
// see "Optional states for every channel/device" for description of optional states
//            "adapter.instance.channelName.state-working",             // optional
//            "adapter.instance.channelName.state-direction",           // optional
//            "adapter.instance.channelName.state-maintenance"          // optional
//            "adapter.instance.channelName.state-maintenance-unreach"  // optional

```


##### blind - Attributes description

```javascript
// BLIND CHANNEL
{
   "_id": "adapter.instance.channelName", // e.g. "hm-rpc.0.JEQ0205615:1"
   "type": "channel",
   "parent": "device or empty",         // e.g. "hm-rpc.0.JEQ0205615",
    "children": [
       "adapter.instance.channelName.state-level",               // mandatory
       "adapter.instance.channelName.state-working",             // optional
       "adapter.instance.channelName.state-direction",           // optional
       "adapter.instance.channelName.state-maintenance"          // optional
       "adapter.instance.channelName.state-maintenance-unreach"  // optional
   ],
   "common": {
       "name":  "Name of channel",      // mandatory, default _id ??
      "role":  "blind"                 // optional   default undefined
       "desc":  ""                      // optional,  default undefined
   }
},
// BLIND STATES
// Important: 0% - blind is fully closed, 100% blind is fully opened
{
   "_id": "adapter.instance.channelName.state-level", // e.g. "hm-rpc.0.JEQ0205615:1.LEVEL"
   "type": "state",
   "parent": "channel or device",       // e.g. "hm-rpc.0.JEQ0205615:1"
   "common": {
       "name":  "Name of state",        // mandatory, default _id ??
       "def":   0,                      // optional,  default 0
       "type":  "number",               // optional,  default "number"
       "read":  true,                   // mandatory, default true
       "write": true,                   // mandatory, default true
       "min":   0,                      // optional,  default 0
       "max":   100,                    // optional,  default 100
       "unit":  "%",                    // optional,  default %
       "role":  "level.blind"           // mandatory
       "desc":  ""                      // optional,  default undefined
   }
}
// see "Optional states for every channel/device" for description of optional states
//            "adapter.instance.channelName.state-working",             // optional
//            "adapter.instance.channelName.state-direction",           // optional
//            "adapter.instance.channelName.state-maintenance"          // optional
//            "adapter.instance.channelName.state-maintenance-unreach"  // optional

```


##### phone - Attributes description
| **Name**       | **common.role**          | **M** | **W** | **common.type** | **Description**
| -------------- |:-------------------------|:-----:|:-----:|-----------------|---
| ringing_number | text.phone_number        |       |       | string          |
| ringing        | indicator                |       |       | boolean         |

...

#### device

#### enum

* common.members - (optional) array of enum member IDs


#### meta

id

 * *&lt;adapter-name&gt;.&lt;instance-number&gt;.meta.&lt;meta-name&gt;*
 * *&lt;adapter-name&gt;.meta.&lt;meta-name&gt;*
 * system.*meta.&lt;meta-name&gt;*



#### adapter

id *system.adapter.&lt;adapter.name&gt;*

* children                  - (optional)  array of adapter instance IDs
* common.mode               - (mandatory) possible values see below
* common.version            - (mandatory) available version
* common.installedVersion   - (mandatory) installed version
* common.enabled            - (mandatory) value should be false so new instances are disabled by default
* common.platform           - (mandatory) possible values: Javascript/Node.js, more coming
* common.webservers         - (optional) array of webserver instances that should serve content from the adapters www folder
* common.noRepository       - (optional) if adapter delivered with initial installation or has own repository
* common.messagebox         - (optional)  true if message box supported. If yes, the object system.adapter.&lt;adapter.name&gt&lt;adapter.instance&gt.messagebox will be created to send messges to adapter (used for email, pushover,...;
* common.wakeup             - (optional)  
* common.run                - (optional)  
* common.availableModes     - (optional) values for common.mode if more than one mode is possible
* common.localLink          - (optional) link to the web service of this adapter. E.g to http://localhost:5984/_utils for futon from admin
* common.logTransporter     - (optional) if this adapter receives logs from other hosts and adapters (e.g. to strore them somewhere)
* common.nondeletable       - (optional) this adapter cannot be deleted or updated. It will be updated together with controller.
* common.icon               - (optional) name of the local icon (should be located in subdirectory "admin")
* common.extIcon            - (optional) link to extrenal icon for uninstalled adapters. Normally on github.
* common.logLevel           - (optional) debug, info, warn or error
* common.supportStopInstance- (optional) if adapter supports signal stopInstance (messagebox required). The signal will be snet before stop to the adapter. (used if the problems occured with SIGTERM)
* common.allowInit          - (optional) allow for "scheduled" adapter call not in time schedule if settings changed or adapter started.
* common.onlyWWW            - (optional) say to controller, that adapter has only html files and no main.js, like rickshaw
* common.singleton          - (optional) adapter can be installed only once in whole system
* common.singletonHost      - (optional) adapter can be installed only once on one host
* common.allowInit          - (optional) allow scheduled adapter start once after configuration changed and then by schedule


#### instance

id *system.adapter.&lt;adapter.name&gt;.&lt;instance-number&gt;*

* parent            - (mandatory) adapter id
* common.host       - (mandatory) host where the adapter should be started at - object *system.host.&lt;host&gt;* must exist
* common.enabled    - (mandatory)
* common.mode       - (mandatory) possible values see below


##### adapter/instance common.mode

* **none**        - this adapter doesnt start a process
* **daemon**      - always running process (will be restarted if process exits)
* **subscribe**   - is started when state *system.adapter.&lt;adapter-name&gt;.&lt;instance-number&gt;.alive* changes to *true*. Is killed when *.alive* changes to *false* and sets *.alive* to *false* if process exits (will **not** be restarted when process exits)
* **schedule**    - is started by schedule found in *system.adapter.&lt;adapter-name&gt;.&lt;instance-number&gt;.schedule* - reacts on changes of *.schedule* by rescheduling with new state
* **once**        - this adapter will be started every time the system.adapter.yyy.x object changed. It will not be restarted after termination.

#### host

id *system.host.&lt;host&gt;*

* common.name       - f.e. "system.host.banana"
* common.process
* common.version
* common.platform
* common.cmd
* common.hostname   - f.e. "banana"
* common.address    - array of ip address strings
* common.children

#### config



#### script


* common.platform   - (mandatory) possible Values 'Javascript/Node.js' (more to come)
* common.enabled    - (mandatory) is script activated or not
* common.source     - (mandatory) the script source
* common.engine     - (optional) scriptengine instance that should run this script (f.e. 'javascript.0') - if ommited engine is automatically selected

#### user

* common.name       - (mandatory) Name of user (@HQ: Case insensitive ? @Bluefox your choice, i think case sensitive is ok too)
* common.password   - (mandatory) MD5 Hash of password

#### group

* parent            - (optional) ID of parent group
* children          - (optional) array of group IDs
* common.name       - (mandatory) name of the group
* common.members    - (mandatory) array of user-object IDs
* common.desc       - (optional) group purpose description
