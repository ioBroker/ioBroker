
# Core Concept

There are two fundamentally different data-types in ioBroker. So called **states** and **objects**.

Objects represent rarely changing and larger data, like meta-data of your systems devices, configurations and additional
files. Every Object has to have an attribute "type". See below for more information what object types are available and which
mandatory attributes a object of a specific type needs. Functions like setObject, getObject, ... are provided to you by
the adapter module.

States represent often changing data in your system, like f.e. if a lamp is on or off, if a motion detector detected
some motion, the temperature of your living room or if the button of a remote control is pressed. Contrary to objects
states can be used to trigger actions and states can create history data. To work with states there are several functions
in the adapter module like setState, getState and so on.

For every state there also has to exist a corresponding object with type=state.


# Content
- [Database Schema](#satabase-schema)
    - [IDs](#ids)
        - [Namespaces](#namespaces)
            - [Namespace system.config.](#namespace-systemconfig)
            - [Namespace system.host.&lt;hostname&gt;](#namespace-systemhosthostname)

    - [States](#states)
    - [Objects](#objects)
        - [Mandatory attributes](#mandatory-attributes)
        - [Optional attributes](#optional-attributes)
        - [Tree structure](#tree-structure)
        - [Object types](#object-types)
        - [Attributes for specific object types](#attributes-for-specific-object-types)
            - [state](#state)
                - [state common.history](#state-commonhistory)
                - [state common.role](#state-commonrole)
            - [channel](#channel)
                - [channel common.role](#channel-commonrole)
                - [Channel descriptions](#channel-descriptions)
                    - [Optional states for every channel/device](#optional-states-for-every-channeldevice)
                    - [light.switch - Attributes description](#lightswitch---attributes-description)
                    - [light.dimmer - Attributes description](#lightdimmer---attributes-description)
                    - [blind - Attributes description](#blind---attributes-description)
                    - [phone - Attributes description](#phone---attributes-description)
            - [device](#device)
            - [enum](#enum)
            - [meta](#meta)
            - [adapter](#adapter)
            - [instance](#instance)
            - [host](#host)
            - [config](#config)
            - [script](#script)
            - [user](#user)
            - [group](#group)

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
* q      - quality. Number with following states:

```
  0x00 - 00000000 - good (can be undefined or null)
  0x01 - 00000001 - general bad, general problem
  0x02 - 00000010 - no connection problem

  0x10 - 00010000 - substitute value from controller
  0x40 - 00100000 - substitute value from device or instance
  0x80 - 01000000 - substitute value from sensor

  0x11 - 01000001 - general problem by instance
  0x41 - 01000001 - general problem by device
  0x81 - 10000001 - general problem by sensor

  0x12 - 00010010 - instance not connected
  0x42 - 01000010 - device not connected
  0x82 - 10000010 - sensor not connected

  0x44 - 01000100 - device reports error
  0x84 - 10000100 - sensor reports error
```
Every *state* has to be represented by an object of the type state containing Meta-Data for the state. see below.

## Objects

### Mandatory attributes

Following attributes have to exist in every object:

* _id
* type        - see below for possible values
* common      - an object containing ioBroker specific abstraction properties
* native      - an object containing congruent properties of the target system

### Optional attributes

* common.name - the name of the object (optional but strictly suggested to fill it)

### Tree structure

The tree structure is assembled automatically by names. E.g. ```system.adapter.0.admin``` is parent for ```system.adapter.0.admin.uptime```. Use this name convetion with point ".", as divider of levels.

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

* common.type   (optional - (default is mixed==any type) (possible values: number, string, boolean, array, object, mixed, file)
* common.min    (optional)
* common.max    (optional)
* common.unit   (optional)
* common.def    (optional - the default value)
* common.desc   (optional, string)
* common.read   (boolean, mandatory) - true if state is readable
* common.write  (boolean, mandatory) - true if state is writable
* common.role   (string,  mandatory) - role of the state (used in user interfaces to indicate which widget to choose, see below)
* common.states (optional) attribute of type number with object of possible states {'value': 'valueName', 'value2': 'valueName2', 0: 'OFF', 1: 'ON'}
* common.workingID (string, optional) - if this state has helper state WORKING. Here must be written the full name or just the last part if the first parts are the same with actual. Used for HM.LEVEL and normally has value "WORKING"


##### state common.history

History function needs the history adapter or any other storage adapter of type history

fifo length is reduced to min when max is hit. set to null or leave undefined to use defaults

for a list of transports see history adapter README

* common.history (optional)
* common.history.HISTORY-INSTANCE.changesOnly (optional, boolean, if true only value changes are logged)
* common.history.HISTORY-INSTANCE.enabled (boolean)


##### state common.role
* common.role (indicates how this state should be represented in user interfaces)

[possible values](STATE_ROLES.md)


#### channel

##### channel common.role (optional)

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
       "name":  "Name of state",        // mandatory, default _id ??
       "def":   false,                  // optional,  default false
       "type":  "boolean",              // optional,  default "boolean"
       "read":  true,                   // mandatory, default true
       "write": false,                  // mandatory, default false
       "min":   false,                  // optional,  default false
       "max":   true,                   // optional,  default true
       "role":  "indicator.maintenance" // mandatory
       "desc":  "Problem description"   // optional,  default undefined
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

*Notice:* all flags are optional except special marked as **mandatory**.

* children                  - array of adapter instance IDs
* common.name               - (mandatory) name of adapter without "ioBroker."
* common.title              - (deprecated) longer name of adapter to show in admin
* common.titleLang          - (mandatory) longer name of adapter in all supported languages like {en: 'Adapter', de: 'adapter', ru: 'Драйвер'}
* common.mode               - (mandatory) possible values see below
* common.version            - (mandatory) available version
* common.installedVersion   - (mandatory) installed version
* common.enabled            - (mandatory) [true/false] value should be false so new instances are disabled by default
* common.platform           - (mandatory) possible values: Javascript/Node.js, more coming
* common.webservers         - array of web server's instances that should serve content from the adapters www folder
* common.noRepository       - [true/false] if adapter delivered with initial installation or has own repository
* common.messagebox         - true if message box supported. If yes, the object system.adapter.&lt;adapter.name&gt&lt;adapter.instance&gt.messagebox will be created to send messges to adapter (used for email, pushover,...;
* common.subscribe          - name of variable, that is subscribed automatically
* common.subscribable       - variables of this adapter must be subscribed with sendTo to enable updates
* common.wakeup             -
* common.availableModes     - values for common.mode if more than one mode is possible
* common.localLink          - link to the web service of this adapter. E.g to http://localhost:5984/_utils for futon from admin
* common.logTransporter     - if this adapter receives logs from other hosts and adapters (e.g. to strore them somewhere)
* common.nondeletable       - [true/false] this adapter cannot be deleted or updated. It will be updated together with controller.
* common.icon               - name of the local icon (should be located in subdirectory "admin")
* common.extIcon            - link to external icon for uninstalled adapters. Normally on github.
* common.logLevel           - debug, info, warn or error
* common.supportStopInstance- [true/false] if adapter supports signal stopInstance (**messagebox** required). The signal will be sent before stop to the adapter. (used if the problems occured with SIGTERM)
* common.allowInit          - [true/false] allow for "scheduled" adapter to be called "not in the time schedule", if settings changed or adapter started.
* common.onlyWWW            - [true/false] say to controller, that adapter has only html files and no main.js, like rickshaw
* common.singleton          - adapter can be installed only once in whole system
* common.singletonHost      - adapter can be installed only once on one host
* common.allowInit          - [true/false] allow scheduled adapter start once after configuration changed and then by schedule
* common.config.width       - default width for configuration dialog
* common.config.height      - default height for configuration dialog
* common.config.minWidth    - minimal width for configuration dialog
* common.config.minHeight   - minimal height for configuration dialog
* common.os                 - string or array of supported operation systems, e.g ["linux", "darwin"]
* common.stopBeforeUpdate   - [true/false] if adapter must be stopped before update
* common.adminTab.singleton - [true/false] if adapter has TAB for admin. Only one TAB for all instances will be shown.
* common.adminTab.name      - name of TAB in admin
* common.adminTab.link      - link for iframe in the TAB. You can use parameters replacement like this: "http://%ip%:%port%". IP will be replaced with host IP. "port" will be extracted from native.port.
* common.adminTab.ignoreConfigUpdate - do not update config TAB if configuration changed (to enable configure settings in TAB)
* common.restartAdapters    - array with names of adapter that must be restarted after this adapter is installed, e.g. ["vis"]
* common.preserveSettings   - string (or array) with names of attributes in common of instance, which will not be deleted. E.g. "history", so by setState('system.adapter.mqtt.0", {..}) the field common.history will not be deleted even if new object does not have this field. To delete the attribute it must be explicitly done with ```common:{history: null}```.
* common.noConfig           - [true/false] do not show configuration dialog for instance
* common.stopTimeout        - timeout in ms to wait, till adapter shut down. Default 500ms.
* common.unsafePerm         - [true/false] if the package must be installed with "npm --unsafe-perm" parameter
* common.supportCustoms     - [true/false] if the adapter support settings for every state. It has to have custom.html file in admin. Sample can be found in ioBroker.history
* common.getHistory         - [true/false] if adapter supports getHistory message
* common.blockly            - [true/false] if adapter has custom blocks for blockly. (admin/blockly.js required)
* common.webExtendable      - [true/false] if web server in this adapter can be extended with plugin/extensions like proxy, simple-api
* common.webExtension       - relative filename to connect the web extension. E.g. in simple-api "lib/simpleapi.js" relative to the adapter root directory. Additionally is native.webInstance required to say where this extension will be included. Empty means, it must run as own web service. "*" means every web server must include it.
* common.welcomeScreen      - array of pages, that should be shown on the "web" index.html page. ["vis/edit.html", "vis/index.html"] or [{"link": "vis/edit.html", "name": "Vis editor", "img": "vis/img/edit.png", "color": "blue"}, "vis/index.html"]
* common.unchanged          - (system) please do not use this flag. It is a flag to inform the system, that configuration dialog must be shown in admin.
* common.serviceStates      - [true/false or path] if adapter can deliver additional states. If yes, the path adapter/lib/states.js will be called and it give following parameters function (objects, states, instance, config, callback). The function must deliver the array of points with values like function (err, result) { result = [{id: 'id1', val: 1}, {id: 'id2', val: 2}]}
* common.nogit              - if true, no install from github directly is possible
* common.materialize        - if adapter supports > admin3 (materialize style)
* common.materializeTab     - if adapter supports > admin3  for tab (materialize style)
* common.dataFolder         - folder relative to iobroker-data where the adapter stores the data. This folder will be backed up and restored automatically. You can use variable '%INSTANCE%' in it.
* common.webPreSettings     - list of parameters that must be included into info.js by webServer adapter. (Example material)
* common.apt-get            - list of debian packages, that required for this adapter (of course only debian)
* common.eraseOnUpload      - erase all previous data in the directory before upload
* common.webByVersion       - show version as prefix in web adapter (usually - ip:port/material, webByVersion - ip:port/1.2.3/material)
* common.noIntro            - never show instances of this adapter on Intro/Overview screen in admin (like icons, widgets)

#### instance

id *system.adapter.&lt;adapter.name&gt;.&lt;instance-number&gt;*

* parent            - (mandatory) adapter id
* common.host       - (mandatory) host where the adapter should be started at - object *system.host.&lt;host&gt;* must exist
* common.enabled    - (mandatory)
* common.mode       - (mandatory) possible values see below


##### adapter/instance common.mode

* **none**        - this adapter doesn't start a process
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
* common.engine     - (optional) *scriptengine* instance that should run this script (f.e. 'javascript.0') - if omitted engine is automatically selected

#### user

* common.name       - (mandatory) Name of user (@HQ: Case insensitive ? @Bluefox your choice, i think case sensitive is ok too)
* common.password   - (mandatory) MD5 Hash of password

#### group

* parent            - (optional) ID of parent group
* children          - (optional) array of group IDs
* common.name       - (mandatory) name of the group
* common.members    - (mandatory) array of user-object IDs
* common.desc       - (optional) group purpose description
