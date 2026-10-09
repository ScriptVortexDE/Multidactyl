# Changelog

## 1.2.0 – 2026-10-09

### Multidactyl Setup

- Neu: **Dev-Instanz** in der Verwaltung: Pterodactyl 2.0-develop als zweite, getrennte Installation neben dem
  bestehenden Panel (eigene Domain, `/var/www/pterodactyl-dev`, Datenbank `panel_dev`, `pterodactyl-dev.conf`,
  `pteroq-dev`) mit Installieren, Aktualisieren, Logs und Entfernen. Dafür sind Ordner, Datenbank, nginx-Konfiguration
  und Queue-Dienst in den Panel-Funktionen jetzt instanzabhängig.

- Neu: Installation von **Pterodactyl 2.0-develop** (Entwicklungsversion) nach der offiziellen 2.0-Dokumentation,
  mit und ohne Wings: Branch-ZIP, MariaDB ab 10.11 (Repository auf älteren Systemen), Node.js 22 mit npm/Vite-Build,
  nginx `/assets/`-Block, Rückfallebene für geänderte Artisan-Optionen. Update holt den neuesten Branch-Stand.
  Keine Übersetzung und kein Blueprint für 2.0, die Verwaltung erkennt 2.0 und überspringt den 1.x-Versionsvergleich.

## 1.1.1 – 2026-10-09

### Installer

- Behoben: Build scheiterte mit `error:0308010C:digital envelope routines::unsupported`, wenn ältere
  Build-Werkzeuge im Spiel sind (Blueprint bringt `css-loader 5.2.7` mit). Der Legacy-Provider wird jetzt vor dem
  Build erkannt (css-loader < 6, webpack < 5) und beim Fehler in beiden Schreibweisen nachgezogen; die Suche nach
  der Fehlermeldung beschränkt sich auf den aktuellen Lauf.

### Multidactyl Setup

- Übersetzung ist eine eigene Ja/Nein-Abfrage (wie Firewall, Blueprint). Scheitert sie, läuft die Installation
  weiter (Panel auf Englisch) und meldet es am Ende; in der Verwaltung gibt es „Übersetzung anwenden / nachholen“.
- Abbruch nach fertigem Panel (z. B. bei der Übersetzung) führt nicht mehr zur Neuinstallation: Der nächste Start
  setzt fort, holt die Übersetzung nach und richtet Wings/Absicherung ein. Zugangsdaten werden direkt nach dem
  Anlegen des Admin-Kontos gesichert.

- Behoben: `Job for nginx.service failed` beim Paketschritt, wenn eine fehlerhafte `pterodactyl.conf` aus einem
  früheren Lauf in `sites-enabled` lag. Reste werden vor dem Start entfernt, die Konfiguration wird geprüft,
  ein belegter Port 80 (z. B. Apache) wird gemeldet. Alle nginx-Neustarts laufen über denselben Helfer.
- Neustart nach Abbruch entfernt auch die nginx-Reste; ein Panel-Ordner ohne `.env` (z. B. Abbruch von
  GermanDactyl Setup) wird als unvollständige Installation erkannt.

## 1.1.0 – 2026-10-08

### Multidactyl Setup (neu)

- Kompletter TUI-Installer für Pterodactyl Panel, Wings und Pelican unter `setup/`, übernommen von GermanDactyl Setup
  (pavl21/pterodactyl-gui-installer, mit Zustimmung des Autors) und eigenständig weitergeführt. Alle Skripte und
  Bibliotheken werden aus diesem Repository geladen.
- Behoben: `server_tokens` lag im `http`-Kontext und kollidierte auf Debian 13 („directive is duplicate“), die
  Installation brach beim SSL-Schritt ab. Jetzt in den `server`-Blöcken.
- Behoben: `listen 443 ssl http2;` (veraltet seit nginx 1.25.1) wird versionsabhängig durch `http2 on;` ersetzt.
- Übersetzung läuft über `scripts/install.sh` mit Signaturprüfung, Backup und Rollback; Sprache wählbar (`GD_PATCH_LANG`).
- Migration: Konfiguration aus `/etc/germandactyl` wird beim ersten Start übernommen.
- Kurzbefehle `multidactyl` und `mdt`.

### Installer

- Neue Option `-f`: nicht passende Stellen ohne Rückfrage überspringen (für Skripte).

## 1.0.0 – 2026-10-08

Erste Version von **Multidactyl**, ein eigenständiges Projekt auf Basis der deutschen Übersetzung von
GermanDactyl (MIT-Lizenz). Alles, was an die alte Infrastruktur gebunden war, wurde ersetzt.

### Unabhängigkeit

- Patches, Prüfsummen und Installer werden direkt aus diesem Repository geladen
  (`raw.githubusercontent.com/<repo>/main/...`), keine fremden Domains mehr.
- Eigener GPG-Signaturschlüssel, öffentlich unter `patches/multidactyl-signing-key.asc` und fest im Installer.
- Eigene Dokumentation (MkDocs) ohne fremde Social-Links, Spenden-Links oder Domain.
- Die Patches selbst tragen jetzt Multidactyl-Hinweise und verlinken auf dieses Projekt.

### Neu gegenüber GermanDactyl

- **Mehrsprachig:** Patches liegen unter `patches/<sprache>/`, der Installer wählt mit `-L <sprache>` (Standard `de`).
- **Eigene Patch-Quelle:** `MULTIDACTYL_SOURCE` erlaubt einen lokalen Checkout oder eine andere URL-Basis, auch offline.
  Signatur und Prüfsummen werden trotzdem geprüft.
- **Prüfmodus `-c`:** lädt und verifiziert den Patch und testet mit `git apply --check`, verändert nichts
  (Exit-Code 2, wenn er nicht passt).
- **Status `-s`:** Panel-Version, Sprache, installierter Patch, Backups, verfügbare Patches.
- **Auflisten `-l`:** alle Sprachen und Patches, ohne Panel und ohne root.
- **Versionsverwaltung im Browser** (`docs/manager/index.html`): Versionsmatrix, Befehls-Generator mit Sprache,
  lokale Liste eigener Panels, Signaturdaten, Fehlerbehebung.
- `.gitattributes` erzwingt LF, damit Prüfsummen auch nach einem Checkout unter Windows stimmen.

### Behoben (aus GermanDactyl übernommen und korrigiert)

- `README.md` enthielt den Inhalt 50-mal (2,3 MB).
- `.rej`-Dateien wurden nach einer Teil-Installation nicht in allen erlaubten Ordnern eingesammelt.
- Falscher Log-Pfad in der Fehlerbehebung.

### Enthaltene Patches

| Sprache | Panel-Versionen |
| --- | --- |
| de | 1.11.2, 1.11.3, 1.12.2, 1.15.1 |
