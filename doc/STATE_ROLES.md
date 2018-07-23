# State roles

## Common
* state - very common purpose. If you don't know which role the state has, use this one.
* text              (common.type = string)
* text.url          (common.type = string) state val contains a url for usage in an anchor, iframe or img
* html              (common.type = string)
* json              (common.type = string)
* list              (common.type = array)


## Sensor (booleans, read-only)

*common.type=boolean, common.write=false*

* sensor.window         - window opened (true) or closed (false)
* sensor.door           - door opened (true) or closed (false)
* sensor.alarm          - some common alarm
* sensor.alarm.flood    - water leakage
* sensor.alarm.fire     - fire sensor
* sensor.alarm.secure   - door opened, window opened or motion detected during alarm is ON.
* sensor.alarm.power    - No power (voltage = 0)
* sensor.light          - feedback from lamp, that it is ON
* sensor.lock           - actual position of lock
* sensor.motion         - motion sensor
* sensor.rain           - rain detected

## Buttons (booleans, write-only)

*common.type=boolean, common.write=true, common.read=false*

* button
* button.long
* button.stop           - e.g. rollo stop,
* button.start
* button.open.door
* button.open.window

## Values (numbers, read-only)

*common.type=number, common.write=false*

* value
* value.window      (common.states={"0": "CLOSED", "1": "TILTED", "2": "OPEN"}) It is important to have (CLOSED/TILTED/OPEN). Values can differ.
* value.temperature (common.unit='°C' or '°F' or 'K')
* value.humidity
* value.brightness     - luminance level (unit: lux, )
* value.min
* value.max
* value.default
* value.battery         - battery level
* value.valve           - valve level
* value.time            - getTime() of Date() object
* value.interval    (common.unit='sec') - Interval in seconds (can be 0.1 or less)
* value.date        (common.type=string) - Date in form 2015.01.01 (without time)
* value.datetime    (common.type=string) - Date and time in system format
* value.gps.longitude   - gps longitude coordinates
* value.gps.latitude    - gps latitude
* value.gps.elevation   - gps elevation
* value.gps             - longitude and latitude together like '5.56;43.45'
* value.power.consumption (unit=Wh or KWh)
* value.direction   (common.type=number or string, indicates up/down, left/right, 4-way switches, wind-direction, ... )
* value.curtain         - actual position of curtain
* value.blind           - actual position of blind
* value.tilt            - actual tilt position
* value.lock            - actual position of lock
* value.wind.speed      - wind speed
* value.wind.speed.max  - maximal wind speed in last 24h
* value.wind.speed.min  - minimal wind speed in last 24h
* value.wind.direction  - wind direction
* value.wind.gust
* value.pressure        - (unit: mbar)
* value.temperature.windchill -
* value.temperature.dewpoint -
* value.temperature.feelslike -
* value.distance
* value.distance.visibility
* value.radiation
* value.uv
* value.rain.hour
* value.rain.today
* value.snow.hour
* value.snow.today
* value.precipitation.hour
* value.precipitation.today


## Indicators (boolean, read-only)

*common.type=boolean, common.write=false*

The difference of *Indicators* from *Sensors* is that indicators will be shown as small icon. Sensors as a real value.
So the indicator may not be alone in the channel. It must be some other main state inside channel.

* indicator
* indicator.working     - indicates that the target systems is executing something, like blinds or lock opening.
* indicator.reachable   - If device is online
* indicator.connected   - used only for instances. Use indicator.reachable for devices
* indicator.maintenance - indicates system warnings/errors, alarms, service messages, battery empty or stuff like that
* indicator.maintenance.lowbat
* indicator.maintenance.unreach
* indicator.maintenance.alarm
* indicator.lowbat      - true if low battery
* indicator.alarm       - same as indicator.maintenance.alarm
* indicator.alarm.fire  - fire detected
* indicator.alarm.flood - flood detected
* indicator.alarm.secure - door or window is opened


## Levels (numbers, read-write)

With **levels** you can control or set some number value.

*common.type=number, common.write=true*

* level
* level.dimmer          - brightness is dimmer too
* level.blind           - set blind position
* level.temperature     - set desired temperature
* level.valve           - set point for valve position
* level.color.red
* level.color.green
* level.color.blue
* level.color.white     - rgbW
* level.color.hue
* level.color.saturation
* level.color.rgb
* level.color.luminance
* level.color.temperature
* level.timer
* level.timer.sleep    - sleep timer. 0 - off, or in minutes
* ...
* level.volume         - (min=0, max=100) - sound volume, but min, max can differ. min < max
* level.volume.group   - (min=0, max=100) - sound volume, for the group of devices
* level.curtain        - set the curtain position
* level.tilt           - set the tilt position of blinds

## Switches (booleans, read-write)

Switch controls boolean device (true = ON, false = OFF)

*common.type=boolean, common.write=true*

* switch
* switch.lock           - lock (true - open lock, false - close lock)
* switch.lock.door      - door lock
* switch.lock.window    - window lock
* switch.boost          - start/stop boost mode of thermostat
* switch.light
* switch.comfort        - comfort mode
* switch.enable
* switch.power          - power on/off


## Media

Special roles for media players

* button.stop
* button.play
* button.next
* button.prev
* button.pause
* switch.pause
* button.forward
* button.reverse
* button.fastforward
* button.fastreverse
* button.volume.up
* button.volume.down
* media.seek            - (common.type=number) %
* media.mode.shuffle    - (common.type=number) 0 - none, 1 - all, 2 - one
* media.mode.repeat     - (common.type=boolean)
* media.state           - ['play','stop','pause'] or [0 - pause, 1 - play, 2 - stop] or [true - playing/false - pause]
* media.artist
* media.album
* media.title
* media.title.next
* media.cover           - cover url
* media.cover.big       - big cover url
* media.cover.small     - tiny cover url
* media.duration.text   - e.g "2:35"
* media.duration        - (common.type=number) seconds
* media.elapsed.text    - e.g "1:30"
* media.elapsed         - (common.type=number) seconds
* media.mute            - (common.type=boolean) true is muted
* media.mute.group      - (common.type=boolean) mute of group of devices
* media.tts             - text to speech
* media.bitrate         - kbps
* media.genre           - genre song
* media.date            - year song
* media.track           - current play track id [0 - ~]
* media.playid          - media player track id
* media.add             - add current playlist
* media.clear           - clear current playlist (write-only)
* media.playlist        - json array like
* media.url             - url to play or current url
* media.url.announcement - URL to play announcement
* media.jump            - Number of items to jump in the playlist (it can be negative)
* media.content         - Type of media being played such as audio/mp3
* media.link            - State with the current file
* media.input           - number or string of input (AUX, AV, TV, SAT, ...)
* level.bass            - Bass level
* level.treble          - Treble level
* switch.power.zone     - power zone

```
[
    {
        "artist": "",
        "album": "",
        "bitrate":0,
        "title": "",
        "file": "",
        "genre": "",
        "year": 0,
        "len": "00:00",
        "rating": "",
        "cover": ""
    }
]
```

* media.browser         - json array like "files"

```
[
    {
        "fanart": "",
        "file": "",//smb://192.168.1.10/music/AtlantidaProject/
        "filetype": "", //directory
        "label": "",
        "lastmodified": "",
        "mimetype": "",
        "size": 0,
        "thumbnail": "",
        "title": "",
        "type": "",
        "lastmodified": "2016-02-27 16:05:46",
        "time": "88",
        "track": "01",
        "date": "2005",
        "artist": "yonderboy (H)",
        "album": "splendid isolation",
        "genre": "Trip-Hop"
    }
]
```
## Info
* info.ip        - ip of device
* info.mac       - mac of device
* info.name      - name of device
* info.address   - some other address (e.g. KNX)
* info.port      - tcp port
* info.standby   - true if device in standby mode
* info.status    - status of device
* info.display   - information shown on device display

## Others

* url
* url.icon               - icon (additionally every object can have common.icon)
* url.cam                - web camera url
* url.blank              - open URL in new window
* url.same               - open URL in this window
* url.audio              - URL for audio file
* text.phone             - phone number

* adapter.messagebox     (common.type=object, common.write=true) used to send messages to email, pushover and other adapters
* adapter.wakeup         (common.type=boolean, common.write=true) wake up adapter from suspended mode
