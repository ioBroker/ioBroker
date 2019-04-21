# State roles

## Common
* state - very common purpose. If you don't know which role the state has, use this one.
* text              (common.type = string)
* text.url          (common.type = string) state val contains a url for usage in an anchor, iframe or img
* html              (common.type = string)
* json              (common.type = string)
* list              (common.type = array)
* date              (common.type = string - parsable by "new Date(ddd)" string
* date              (common.type = number - epoch seconds * 1000


## Sensor (booleans, read-only)

*common.type=boolean, common.write=false*

* sensor.alarm          - some common alarm
* sensor.alarm.fire     - fire sensor
* sensor.alarm.flood    - water leakage
* sensor.alarm.power    - No power (voltage = 0)
* sensor.alarm.secure   - door opened, window opened or motion detected during alarm is ON.
* sensor.door           - door opened (true) or closed (false)
* sensor.light          - feedback from lamp, that it is ON
* sensor.lock           - actual position of lock
* sensor.motion         - motion sensor
* sensor.noise          - noise detected
* sensor.rain           - rain detected
* sensor.window         - window opened (true) or closed (false)

## Buttons (booleans, write-only)

*common.type=boolean, common.write=true, common.read=false*

* button
* button.long
* button.mode.*
* button.mode.auto
* button.mode.manual
* button.mode.silent
* button.open.door
* button.open.window
* button.start
* button.stop           - e.g. rollo stop,

## Values (numbers, read-only)

*common.type=number, common.write=false*

* value
* value.battery         - battery level
* value.blind           - actual position of blind
* value.brightness      - luminance level (unit: lux, )
* value.current         - Current in Amper, unit=A
* value.curtain         - actual position of curtain
* value.default
* value.direction       - (common.type=number ~~or string~~, indicates up/down, left/right, 4-way switches, wind-direction, ... )
* value.distance
* value.distance.visibility
* value.gps             - longitude and latitude together like '5.56;43.45'
* value.gps.elevation   - gps elevation
* value.gps.latitude    - gps latitude
* value.gps.longitude   - gps longitude coordinates
* value.humidity
* value.interval    (common.unit='sec') - Interval in seconds (can be 0.1 or less)
* ~~value.date        (common.type=string) - Date in form 2015.01.01 (without time)~~
* ~~value.datetime    (common.type=string) - Date and time in system format~~
* value.lock            - actual position of lock
* value.max
* value.min
* value.power.consumption (unit=Wh or KWh)
* value.pressure        - (unit: mbar)
* value.severity        - some severity (states can be provided), Higher is more important
* value.speed           - wind speed
* value.sun.azimuth     - sun azimuth in °
* value.sun.elevation   - sun elevation in °
* value.temperature (common.unit='°C' or '°F' or 'K')
* value.tilt            - actual tilt position
* value.time            - getTime() of Date() object
* value.valve           - valve level
* value.voltage         - Voltage in Volt, unit=V
* value.warning         - some warning (states can be provided), Higher is more important
* value.window      (common.states={"0": "CLOSED", "1": "TILTED", "2": "OPEN"}) It is important to have (CLOSED/TILTED/OPEN). Values can differ.

## Indicators (boolean, read-only)

*common.type=boolean, common.write=false*

The difference of *Indicators* from *Sensors* is that indicators will be shown as small icon. Sensors as a real value.
So the indicator may not be alone in the channel. It must be some other main state inside channel.

* indicator
* indicator.alarm       - same as indicator.maintenance.alarm
* indicator.alarm.fire  - fire detected
* indicator.alarm.flood - flood detected
* indicator.alarm.secure - door or window is opened
* indicator.connected   - used only for instances. Use indicator.reachable for devices
* indicator.lowbat      - true if low battery
* indicator.maintenance - indicates system warnings/errors, alarms, service messages, battery empty or stuff like that
* indicator.maintenance.alarm
* indicator.maintenance.lowbat
* indicator.maintenance.unreach
* indicator.reachable   - If device is online
* indicator.working     - indicates that the target systems is executing something, like blinds or lock opening.


## Levels (numbers, read-write)

With **levels** you can control or set some number value.

*common.type=number, common.write=true*

* level
* level.blind           - set blind position
* level.co2             - 0-100% ait quality
* level.color.blue
* level.color.green
* level.color.hue       - color in ° 0-360; 0=red, 120=green, 240=blue, 360=red(cyclic)
* level.color.luminance
* level.color.red
* level.color.rgb       - hex color like '#rrggbb'
* level.color.saturation
* level.color.temperature - color temperature in K° 2200 warm-white, 6500° cold white
* level.color.white     - rgbW
* level.curtain        - set the curtain position
* level.dimmer          - brightness is dimmer too
* level.temperature     - set desired temperature
* level.tilt           - set the tilt position of blinds
* level.timer
* level.timer.sleep    - sleep timer. 0 - off, or in minutes
* level.valve           - set point for valve position
* level.volume         - (min=0, max=100) - sound volume, but min, max can differ. min < max
* level.volume.group   - (min=0, max=100) - sound volume, for the group of devices

## Switches (booleans, read-write)

Switch controls boolean device (true = ON, false = OFF)

*common.type=boolean, common.write=true*

* switch
* switch.boost          - start/stop boost mode of thermostat
* switch.comfort        - comfort mode
* switch.enable
* switch.light
* switch.lock           - lock (true - open lock, false - close lock)
* switch.lock.door      - door lock
* switch.lock.window    - window lock
* switch.mode.*
* switch.mode.auto      - auto mode on/off
* switch.mode.color     - color mode on/off
* switch.mode.manual    - manual mode on/off
* switch.mode.moonlight - moon light mode on/off
* switch.mode.silent    - silent mode on/off
* switch.power          - power on/off

## Media

Special roles for media players

* button.fastforward
* button.fastreverse
* button.forward
* button.next
* button.pause
* button.play
* button.prev
* button.reverse
* button.stop
* button.volume.down
* button.volume.up
* level.bass            - Bass level
* level.treble          - Treble level
* media.add             - add current playlist
* media.album
* media.artist
* media.bitrate         - kbps
* media.broadcastDate   - (common.type=string) Broadcast date
* media.clear           - clear current playlist (write-only)
* media.content         - Type of media being played such as audio/mp3
* media.cover           - cover url
* media.cover.big       - big cover url
* media.cover.small     - tiny cover url
* media.date            - year song
* media.duration        - (common.type=number) seconds
* media.duration.text   - e.g "2:35"
* media.elapsed         - (common.type=number) seconds
* media.elapsed.text    - e.g "1:30"
* media.episode         - (common.type=string) episode number (important the type is really "string" to be able to indicate absence of episode with "")
* media.genre           - genre song
* media.input           - number or string of input (AUX, AV, TV, SAT, ...)
* media.jump            - Number of items to jump in the playlist (it can be negative)
* media.link            - State with the current file
* media.mode.repeat     - (common.type=boolean)
* media.mode.shuffle    - (common.type=number) 0 - none, 1 - all, 2 - one
* media.mute            - (common.type=boolean) true is muted
* media.mute.group      - (common.type=boolean) mute of group of devices
* media.playid          - media player track id
* media.playlist        - json array like
* media.season          - (common.type=string) season number (important the type is really "string" to be able to indicate absence of season with "")
* media.seek            - (common.type=number) %
* media.state           - ['play','stop','pause'] or [0 - pause, 1 - play, 2 - stop] or [true - playing/false - pause]
* media.title
* media.title.next
* media.track           - (common.type=string) current play track id [0 - ~] (important the type is really "string" to be able to indicate absence of track with "")
* media.tts             - text to speech
* media.url             - url to play or current url
* media.url.announcement - URL to play announcement
* switch.pause
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

## Weather
* date                        - actual date or date of last read information
* date.forecast.1                 - tomorrow date
* date.sunrise                - Sunrise for today
* date.sunset                 - Sunset for today
* dayofweek                   - day of week as text
* location                    - Text description of location (e.g. address)
* value.clouds                - Clouds on the sky. 0% - no clouds, 100% - many clouds.
* value.direction.max.wind    - actual wind direction in degrees
* value.direction.min.wind    - actual wind direction in degrees
* value.direction.wind        - actual or average wind direction in degrees
* value.direction.wind.forecast.0 - wind direction forecast for today in degrees
* value.direction.wind.forecast.1
* value.humidity              - actual or average humidity
* value.humidity.max          - actual humidity
* value.humidity.min          - actual humidity
* value.precipitation         - (type: number, unit: mm) precipitation for last 24 hours rain/snow (Niederschlag heute für Schnee oder Regen / осадки сегодня снега или дождя)
* value.precipitation.day.forecast.0     - Forecast for precipitation for day time
* value.precipitation.forecast.0  - (type: number, unit: %) Forecast of precipitation chance for today
* value.precipitation.forecast.0  - (type: number, unit: mm) Forecast of precipitation level for today
* value.precipitation.forecast.1  - (type: number, unit: %) Forecast of precipitation chance for tomorrow
* value.precipitation.forecast.1  - (type: number, unit: mm) Forecast of precipitation level for tomorrow
* value.precipitation.hour    - Actual precipitation level in last hour
* value.precipitation.night.forecast.0   - Forecast for precipitation for night time
* value.precipitation.today   - Actual precipitation level for today (till 0:00)
* value.pressure.forecast.0       - forecast for pressure for today
* value.pressure.forecast.1
* value.radiation             - Actual sun radiation level
* value.rain                  - Actual rain level in last 24 hours
* value.rain.hour             - Actual rain level in last hour
* value.rain.today            - Actual rain level for today (till 0:00)
* value.snow                  - Actual snow level in last 24 hours
* value.snow.hour             - Actual snow level in last hour
* value.snow.today            - Actual snow level for today (till 0:00)
* value.snowline              - Actual snow line in meters
* value.speed.max.wind        - maximal wind speed in last 24h
* value.speed.min.wind        - minimal wind speed in last 24h
* value.speed.wind            - actual or average wind speed
* value.speed.wind.forecast.0     - wind speed forecast for today
* value.speed.wind.forecast.1
* value.speed.wind.gust       - actual wind gust speed
* value.temperature           - Actual temperature
* value.temperature.dewpoint  - Actual dewpoint
* value.temperature.feelslike - Actual temperature "feels like"
* value.temperature.max       - Maximal temperature in last 24h
* value.temperature.max.forecast.0  - Max temperature forecast for today
* value.temperature.max.forecast.1
* value.temperature.min       - Minimal temperature in last 24h
* value.temperature.min.forecast.0  - Min temperature forecast for today
* value.temperature.min.forecast.1
* value.temperature.windchill - Actual wind chill
* value.uv                    - Actual UV level
* weather.chart.url           - URL to chart for weather history
* weather.chart.url.forecast  - URL to chart for weather forecast
* weather.direction.wind      - actual or average wind direction as text, e.g. NNW
* weather.direction.wind.forecast.0 - wind direction forecast for today as text
* weather.html                - HTML object with weather description
* weather.icon                - Actual state icon URL for now
* weather.icon.forecast.1         - tomorrow icon
* weather.icon.name           - Actual state icon name for now
* weather.icon.wind           - Actual wind icon URL for now
* weather.json                - JSON object with specific data
* weather.state               - Actual weather description
* weather.state.forecast.0        - Weather description for today
* weather.state.forecast.1        - tomorrow weather state
* weather.title               - Very short description
* weather.title.forecast.0        - Very short description for tomorrow
* weather.title.short         - Very very short description (One word)
* weather.type                - Type of weather information


## Info
* date.end       - string or number
* date.start     - string or number
* info.address   - some other address (e.g. KNX)
* info.display   - information shown on device display
* info.ip        - ip of device
* info.mac       - mac of device
* info.name      - name of device
* info.port      - tcp port
* info.standby   - true if device in standby mode
* info.status    - status of device

## Others

* text.phone             - phone number
* url
* url.audio              - URL for audio file
* url.blank              - open URL in new window
* url.cam                - web camera url
* url.icon               - icon (additionally every object can have common.icon)
* url.same               - open URL in this window

* adapter.messagebox     (common.type=object, common.write=true) used to send messages to email, pushover and other adapters
* adapter.wakeup         (common.type=boolean, common.write=true) wake up adapter from suspended mode
