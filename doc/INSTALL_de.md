# Installation

## Manuelle Installation von ioBroker auf Debian basierten Linux Systemen (Debian, Ubuntu, Raspbian, ...)

### Voraussetzungen

#### Node.js
 
* x86/amd64 - Linux, Windows, OS X - Download und Installation siehe [Node.js](http://nodejs.org) (Node.js version >= 0.8, inklusive npm)
* ARM - Raspbian - ```wget http://ccu.io.mainskater.de/nodejs_0.10.22-1_armhf.deb ; sudo dpkg -i nodejs_0.10.22-1_armhf.deb ; rm nodejs_0.10.22-1_armhf.deb```

#### Redis

[Redis](http://redis.io/) 

* ```sudo apt-get install redis-server```

#### CouchDB

[CouchDB](http://couchdb.apache.org/) 

* ```sudo apt-get install couchdb```
* in der Datei /etc/couchdb/local.ini die Zeile ```;bind_address = 127.0.0.1``` durch ```bind_address = 0.0.0.0``` ersetzen. (das zu entfernende Semikolon am Zeilenanfang beachten!)
* ```sudo /etc/init.d/couchdb restart``` bzw ```sudo service restart couchdb```


### ioBroker.nodejs herunterladen und installieren

* Verzeichnis erzeugen und Rechte für aktuell benutzten User vergeben

    ```sudo mkdir /opt/iobroker ; sudo chown $USER.$USER /opt/iobroker ; cd /opt/iobroker```
* Das Repository clonen

    ```git clone https://github.com/ioBroker/ioBroker.nodejs /opt/iobroker/```
* Node Module installieren

    ```npm install --production --loglevel error --unsafe-perm```
* Das Kommandozeilen-Tool ausführbar machen 

    ```chmod +x iobroker```
* Datenbankeinrichtung durchführen

    ```./iobroker setup```

    (falls CouchDB und/oder Redis nicht auf 127.0.0.1 erreichbar sind können optional die Argument ```--couch <host> und --redis <host>``` benutzt werden)

* Adapter-Informationen abrufen

    ```./iobroker update```

# Admin-Adapter installieren

Dieser Adapter ist für die grundlegende Systemadministration (Adapter installieren, updaten, konfigurieren) erforderlich

*   ```./iobroker add admin --enabled```

# ioBroker Controller starten

* ```./iobroker start``` ausführen um den Controller als Hintergrunddienst zu starten.
* Logausgabe mit ```tail -f log/iobroker.log``` beobachten

oder

* ```node controller.js``` ausführen um den Controller im Vordergrund laufen zu lassen (Beenden mit Strg-C)


## Admin UI

Der Admin-Adapter startet einen dedizierten Webserver der das Admin UI bereitstellt. Default Port ist 8081, also http://&lt;iobroker&gt;:8081/ im Browser öffnen.


## Direkter Object-Zugriff

Direkter Zugriff auf alle ioBroker Objekte ist über das CouchDB-Webinterface "Futon" http://&lt;couch&gt;:5984/_utils/ gegeben.

## Ereignisse beobachten

Mit dem Kommandozeilen-Tool ```redis_cli``` und dem Kommando ```PSUBSCRIBE *``` ist es möglich alle Ereignisse auf der Konsole zu beobachten


# weitere Adapter installieren

Im Admin UI im Reiter "Adapter" den Button "Instanz erzeugen" anklicken. Konfiguration der neuen Instanz kann dann im Reiter "Instanzen" vorgenommen werden.

