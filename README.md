# evcc-KIA2P-hack
Kia and Hyundai electric vehicles switch to 2-phase charging if charge current is set below 8A.  
This hack is planned to avoid this.  

evcc looks like a predominantely German project to me. So I'll comment in German.  
Please drop a note to ask for english explanations, if required.

----------------------

Kia und Hyundai-EV schalten unter 8A auf 2-phasiges Laden. evcc oszilliert. 
Dieser Hack soll das verhindern

Zitat https://docs.evcc.io/docs/devices/vehicles#kia-bluelink :
> Manche Modelle (z.B. Niro EV) schalten bei geringen Ladeströmen (< 8A) intern auf 2 Phasen um.
> In den Fällen, in denen die Wallbox auch die Phasenströme misst, führt das zu unerwünschten Schwankungen der Ladeleistung.
> Abhilfe schafft hier, den Mindestladestrom auf 8A zu setzen.

Auftreten, Diagnose und Umgang mit diesem Problem hier in der evcc-Diskussion:  
[go-eCharger in Kombi mit Kia Niro EV Ladeverhalten](https://github.com/evcc-io/evcc/discussions/9014)

## Motivation

Der Workround aus dem Manual `minCurrent: 8` setzt effektiv eine Mindestladeleistung von `230 V * 8 A * 3 = 5,5 kW `.  
Das kann für kleine PV-Anlagen selbst im Sommer "sportlich" werden.  
Auch für größere Anlagen limitiert es die PV-Nutzung bei Dämmerung, Winter und Schlechtwetter.

Die Alternative wäre, konstant mit `maxCurrent: 7` den KIA dauerhaft im 2-Phasenbetrieb zu halten.  
Das limitert die Ladeleistung auf ca `230 V * 7 A * 2 = 3,2 kW` - auch bei hohem PV-Überschuss und zum schnellen Nachladen aus dem Netz.

## Ansatz

Eine Hysterese soll das Umschalten zwischen 2-phasigem und 3-phasigem Laden verzögern.
mögliche Parameter:
- Zeitverzug
- Über- / Unterschreiten des verfügbaren PV-Überschusses
- Bezugsparameter: GridPower? ist das eine zirkuläre Referenz? 
- ggf. Alternativ: PV-Power - Home-Power

## Implementierung

- Als separater Demon außerhalb der evcc-sourcen  
- Einbindung per mqtt
- gewählte Sprache: PERL (sorry, kids... ;-)  )

aus `evcc` über `mqtt` Verfügbare Leistungs Daten 
```...:~/tmp/images/futro$ mosquitto_sub -t 'evcc/#' -v -h homeserver | grep -i power
evcc/loadpoints/1/chargePower 0
evcc/site/pv/1/power 2201
evcc/site/pv/2/power 2458
evcc/site/battery/1/power -1
evcc/site/residualPower 100
evcc/site/pvPower 4659
evcc/site/batteryPower -1
evcc/site/gridPower -3491.5
evcc/site/homePower 1166.5
```

Timing:
- es wird erst `chargePower` ausgegeben
- nach ca einer Sekunde die anderen power-Werte im Block
- danach knapp 30 Sekunden Pause
Können wir daraus ableiten, daß `chargePower` in `evcc` aus den Werten der letzten Periode ermittelt wird?
Das würde evtl. Probleme mit Zirkelbezügen entschärfen. Schau' mer mal .... 


