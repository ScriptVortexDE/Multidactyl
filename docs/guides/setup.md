# Multidactyl Setup

Wir möchten mehr als eine Übersetzung bieten: die Installation und Verwaltung von Pterodactyl so einfach wie möglich.
Mit diesem Skript setzt du über eine grafische Oberfläche in deiner SSH-Sitzung ein Pterodactyl Panel samt Wings auf,
alternativ ein Pelican Panel. Du brauchst dafür nur einen Linux-Server und eine eigene Domain.

!!! info "Voraussetzungen"
    - Debian 11, 12 oder 13 bzw. Ubuntu 22.04, 24.04 oder 26.04 (amd64 oder arm64)
    - Root-Rechte
    - Eine Domain bzw. Subdomain, deren A-Eintrag auf diesen Server zeigt (bei Cloudflare: Proxy aus, „DNS only“)
    - Ein frisch aufgesetztes System, auf dem die Ports 80 und 443 frei sind

## Installation

Mit diesem Befehl startest du das Skript:

```shell
sudo bash -c "$(curl -sSL https://raw.githubusercontent.com/ScriptVortexDE/Multidactyl/main/setup/installer.sh)"
```

Ist Pterodactyl bereits installiert, öffnet sich stattdessen die Verwaltung. Später startest du sie jederzeit mit
`multidactyl` oder kurz `mdt`.

## Die Funktionen

### Panel-Installation mit simplen Angaben

Als Erstes kannst du Panel und Wings installieren. Mit nur wenigen Angaben, etwa der Domain und der E-Mail-Adresse
für die SSL-Zertifikate von Let's Encrypt, führst du die Installation über eine grafische Oberfläche durch. Das
Skript prüft vorher, ob die Domain wirklich auf deinen Server zeigt, und erkennt Cloudflare-Proxys, NAT und
unpassende Systeme.

Eingerichtet werden PHP 8.3, MariaDB, Redis, nginx, Composer, Certbot, das Panel mit Cronjob und Queue-Dienst sowie
SSL mit automatischer Erneuerung. Gibt es für die neueste Panel-Version einen Multidactyl-Patch, wird die
Übersetzung automatisch angewendet. Sonst wählst du zwischen der neuesten Version auf Englisch und der neuesten
übersetzten Version.

### Automatische Kontoerstellung

Das Administrator-Konto wird bei der Installation automatisch angelegt. Am Ende bekommst du zufällig generierte
Zugangsdaten angezeigt und kannst sie auf Wunsch in einer Datei speichern, die nur root lesen kann.

### Wings ganz leicht integrieren

Liegen Panel und Wings auf demselben Server, ist danach alles fertig: Docker, Wings, eine automatisch angelegte
Node, die Konfiguration, ein Portbereich für Gameserver und die Verbindung zum Panel. Läuft Wings auf einem anderen
Server, brauchst du nur zwei Angaben (Domain und E-Mail) und fügst anschließend den Befehl aus dem Panel ein
(„Generate Token“). Damit keine Fehler auftreten, prüft das Skript mit einigen Tests, ob alles richtig eingerichtet
ist. Falls nicht, bekommst du in den meisten Fällen einen Lösungsvorschlag.

### Absicherung des Servers

Wählbar bei der Installation und jederzeit in der Verwaltung: UFW-Firewall, die deinen SSH-Port automatisch
freigibt, fail2ban gegen Angriffe auf SSH, automatische Sicherheitsupdates und tägliche verschlüsselte Backups
(restic, inkrementell, inklusive Datenbanken).

### Allgemeine Verwaltung von Pterodactyl

Im laufenden Betrieb möchtest du dir Verwaltung und Wartung leicht machen. Dafür gibt es die Verwaltung mit
Statuszeile und diesen Bereichen:

| Bereich | Funktionen |
| --- | --- |
| Hilfe & Analyse | Analyse mit automatischer Reparatur, „Ich habe mich ausgesperrt“, Panel reparieren, Panel nicht erreichbar, SSL-Zertifikate prüfen/erneuern, Logs, Support-Paket |
| Aktualisieren | Panel, Wings, Blueprint, System-Pakete |
| Backups | Backups erstellen, wiederherstellen, automatische Backups einrichten |
| Gameserver & Wings | Wings installieren/verwalten, Ports freigeben, Swap verwalten |
| Erweiterungen & Aussehen | Blueprint und Erweiterungen, Themes, Original-Oberfläche wiederherstellen |
| Datenbanken | phpMyAdmin, Database-Host für Gameserver |
| Server & Sicherheit | Firewall, fail2ban, automatische Updates, SSH-Loginseite |
| Deinstallieren | Panel, Wings und alle Komponenten sauber entfernen |

### Pelican Panel (Beta)

Alternativ installiert das Skript das Pelican Panel samt Pelican Wings. Pelican bringt Deutsch bereits mit, ein
Übersetzungs-Patch ist dort nicht nötig.

## Besser als das Original

Multidactyl Setup basiert auf GermanDactyl Setup und behält den kompletten Funktionsumfang. Dazu kommen:

- **Behoben:** Die Installation brach auf Debian 13 beim SSL-Schritt ab (`"server_tokens" directive is duplicate`).
- **Behoben:** Die veraltete nginx-Form `listen 443 ssl http2;` wird auf neuen Versionen durch `http2 on;` ersetzt.
- **Behoben:** `Job for nginx.service failed` beim Paketschritt, wenn eine fehlerhafte `pterodactyl.conf` aus einem
  abgebrochenen Lauf in `sites-enabled` lag. Reste werden vor dem Start entfernt, die Konfiguration wird geprüft, ein
  belegter Port 80 (z. B. Apache) wird im Fehlerdialog genannt.
- **Behoben:** Der Build der Übersetzung scheiterte mit Blueprint (`error:0308010C:digital envelope routines`),
  weil Blueprints `css-loader 5` auf Node 22 den OpenSSL-Legacy-Provider braucht. Der Installer erkennt das jetzt
  vor dem Build und beim Fehler in beiden Schreibweisen.
- **Besser:** Bricht die Installation erst nach dem fertigen Panel ab (Übersetzung, Wings, Absicherung), wird beim
  nächsten Start fortgesetzt statt alles zu löschen. Zugangsdaten werden direkt nach dem Anlegen des Kontos gesichert,
  die Übersetzung kann nachgeholt werden.
- **Neu:** Die Übersetzung ist eine eigene Ja/Nein-Abfrage im Setup, wie Firewall und Blueprint. Bei „Nein“
  bleibt das Panel auf Englisch. Scheitert die Übersetzung, bricht die Installation nicht mehr ab; das Panel läuft
  dann auf Englisch, und die Übersetzung lässt sich in der Verwaltung unter „Erweiterungen & Aussehen“ nachholen.
- **Behoben:** Der Neustart nach einem Abbruch entfernt auch die nginx-Reste. Ein Panel-Ordner ohne `.env`, etwa nach
  einem Abbruch von GermanDactyl Setup, wird als unvollständige Installation erkannt.
- **Sicherer:** Die Übersetzung wird mit Signatur- und Prüfsummenprüfung angewendet, mit Backup und Rollback.
- **Unabhängig:** Alle Skripte werden aus diesem Repository geladen, nichts von fremden Servern.
- **Mehrsprachig vorbereitet:** Sprache der Übersetzung über `GD_PATCH_LANG` (Standard `de`).
- **Migration:** Server, die mit GermanDactyl Setup eingerichtet wurden, werden erkannt. Die Konfiguration aus
  `/etc/germandactyl` wird beim ersten Start übernommen.

!!! tip "Lokaler Checkout"
    Zum Testen oder ohne Internet kannst du das Repository klonen und das Setup direkt starten. Bibliotheken und
    Patches werden dann aus dem Checkout geladen:

    ```shell
    git clone https://github.com/ScriptVortexDE/Multidactyl.git /opt/multidactyl
    sudo bash /opt/multidactyl/setup/installer.sh
    ```

!!! info "Info bei fehlerhaften Angaben"
    Startet das Skript bei dir nicht oder stimmt etwas nicht, eröffne bitte ein
    [Issue](https://github.com/ScriptVortexDE/Multidactyl/issues) und hänge das Log aus `/var/log/multidactyl-setup/` an.

## Verwendete Projekte

Einige Teile des Skripts nutzen Software anderer Entwickler im Hintergrund:

- **Let's Encrypt / Certbot:** SSL-Zertifikate, 90 Tage gültig, automatische Erneuerung per Hook. Prüfen und
  erneuern kannst du sie in der Verwaltung unter „Hilfe & Analyse“.
- **Blueprint:** Themes und Erweiterungen werden über [Blueprint](https://blueprint.zip) installiert. Die früheren
  Farbthemes von Sigma-Production sind mit aktuellen Panels nicht mehr kompatibel.
- **restic:** verschlüsselte, inkrementelle Backups.
- **phpMyAdmin**, **Docker**, **NodeSource** (Node.js 22) und **packages.sury.org** (PHP 8.3).
