# State roles

## Common
* state - very common purpose. If you don't know which role the state has, use this one.
* text              (common.type = string)
* text.url          (common.type = string) state val contains a url for usage in an anchor, iframe or img
* html              (common.type = string)
* json              (common.type = string)
* list              (common.type = array)


## States (booleans, read-only)

*common.type=boolean, common.write=false*

* state.window - window opened (true) or closed (false)
* state.door   - door opened (true) or closed (false)
* state.alarm  -
* state.alarm.flood -
* state.alarm.fire -
* state.alarm.secure - door opened, window opened or motion detected during alarm is ON.
* state.alarm.power - No power (voltage = 0)
* state.light  - feedback from lamp, that it is ON


## Buttons (booleans, write-only)

*common.type=boolean, common.write=true, common.read=false*

* button
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


## Values (numbers, read-only)

*common.type=number, common.write=false*

* value
* value.window      (common.states={"0": "CLOSED", "1": "TILTED", "2": "OPEN"}) It is important to have (CLOSED/TILTED/OPEN). Values can differ.
* value.temperature (common.unit='°C' or '°F' or 'K')
* value.humidity
* value.brightness
* value.min
* value.max
* value.default
* value.battery      - battery level
* value.valve        - valve level
* value.time         - getTime() of Date() object
* value.interval    (common.unit='sec') - Interval in seconds (can be 0.1 or less)
* value.date        (common.type=string) - Date in form 2015.01.01 (without time)
* value.datetime    (common.type=string) - Date and time in system format
* value.gps.longitude - gps longitude coordinates
* value.gps.latitude - gps latitude
* value.gps         - longitude and latitude together like '5.56;43.45'
* value.power.consumption (unit=Wh or KWh)
* value.direction   (common.type=number or string, indicates up/down, left/right, 4-way switches, wind-direction, ... )
* value.curtain     - actual position of curtain
* value.blind       - actual position of blind
* value.tilt        - actual tilt position
* value.wind.speed  - wind speed
* value.wind.direction - wind direction

## Indicators (boolean, read-only)
*common.type=boolean, common.write=false*

The difference of *Indicators* from *States* is that indicators will be shown as small icon. States as real value.
So the indicator may not be alone in the channel. It must be some other main state inside channel.

* indicator
* indicator.working     - indicates that the target systems is executing something, like blinds or lock opening.
* indicator.reachable
* indicator.connected
* indicator.maintenance - indicates system warnings/errors, alarms, service messages, battery empty or stuff like that
* indicator.maintenance.lowbat
* indicator.maintenance.unreach
* indicator.maintenance.alarm
* indicator.battery     - true if low battery
* indicator.alarm       - same as indicator.maintenance.alarm
* indicator.alarm.fire  - fire detected
* indicator.alarm.flood - flood detected
* indicator.alarm.secure - door or window is opened


## Levels (numbers, read-write)

*common.type=number, common.write=true*

* level
* level.dimmer          - brightness is dimmer too
* level.blind           - set blind position
* level.temperature     - set desired temperature
* level.valve           - set point for valve position
* level.color.red
* level.color.green
* level.color.blue
* level.color.hue
* level.color.saturation
* level.color.rgb
* level.color.luminance
* level.color.temperature
* ...
* level.volume          (min=0, max=100) - sound volume, but min, max can differ. min < max
* level.curtain        - set the curtain position
* level.tilt           - set the tilt position of blinds

## Switches (booleans, read-write)

*common.type=boolean, common.write=true*

* switch
* switch.lock - lock
* switch.lock.door - door lock
* switch.lock.window - window lock


## Others

* text.phone             - phone number

* adapter.messagebox     (common.type=object, common.write=true) used to send messages to email, pushover and other adapters
* adapter.wakeup         (common.type=boolean, common.write=true) wake up adapter from suspended mode
