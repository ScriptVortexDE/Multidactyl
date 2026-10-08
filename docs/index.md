# Multicatyl – Willkommen!

Multicatyl übersetzt das [Pterodactyl Panel](https://pterodactyl.io/) in andere Sprachen – sowohl das Server- als auch das Adminpanel. Englisch bleibt dabei immer erhalten.

## Wie funktioniert das?

Pterodactyl bringt offiziell nur Englisch mit, und viele Texte sind fest in die Oberfläche eingebaut (hartcodiert). Multicatyl ergänzt deshalb die gewünschte Sprache als eigene Sprachdateien (`resources/lang/<sprache>`) und übersetzt die fest eingebauten Texte per Patch. Mit einem einzigen Befehl ist dein Panel übersetzt – [hier geht's zur Installation](installation.md).

Aktuell enthalten: **Deutsch** (`de`) für Panel-Version **v1.15.1**.

!!! tip "Versionsverwaltung im Browser"
    In der [Versionsverwaltung](manager/index.html) siehst du auf einen Blick, welche Panel-Version aktuell ist,
    baust dir den passenden Installationsbefehl zusammen und behältst den Patch-Stand deiner eigenen Panels im Blick.

## Was Multicatyl ausmacht

- **Signierte Patches:** Jeder Patch wird vor dem Anwenden gegen eine GPG-signierte Prüfsummenliste geprüft.
- **Backup und Rollback:** Vor jeder Änderung wird gesichert, bei einem fehlgeschlagenen Build automatisch zurückgespielt.
- **Prüfen ohne Risiko:** Mit `-c` siehst du vorher, ob der Patch zu deinem Panel passt.
- **Mehrere Sprachen:** Jede Sprache liegt in einem eigenen Ordner `patches/<sprache>/` und wird mit `-L <sprache>` gewählt.
- **Eigene Quelle:** Mit `MULTICATYL_SOURCE` installierst du aus einem lokalen Checkout, auch ohne Internet.

## Herkunft

Die deutschen Übersetzungen basieren auf [GermanDactyl](https://github.com/pavl21/GermanDactyl) (MIT-Lizenz). Multicatyl ist davon unabhängig und wird eigenständig weiterentwickelt.
