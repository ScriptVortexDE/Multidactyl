# Skripte

In diesem Ordner liegen die Skripte für die Installation von Multicatyl und für das Erstellen neuer Patches.

| Skript | Zweck |
| --- | --- |
| [install.sh](install.sh) | Installiert Multicatyl in einem bestehenden Panel, entfernt es wieder (`-u`), prüft (`-c`) oder zeigt den Status (`-s`) |
| [startPatching.sh](startPatching.sh) | Wechselt in den Patch-Modus, um eine neue Panel-Version zu übersetzen |
| [createPatch.sh](createPatch.sh) | Erstellt aus den Änderungen den neuen Patch und verlässt den Patch-Modus |
| [installAddon.sh](installAddon.sh) | **[Nicht fertig]** Installiert ein Addon |

## install.sh

```bash
curl -fsSL https://raw.githubusercontent.com/hahn1315/Multicatyl/main/scripts/install.sh | sudo bash -s -- [Optionen]
```

| Option | Bedeutung |
| --- | --- |
| `-d <pfad>` | Pfad zum Panel (Standard: `/var/www/pterodactyl`) |
| `-L <sprache>` | Sprache des Patches, Standard `de` (Ordner `patches/<sprache>/`) |
| `-v <version>` | Patch für diese Version verwenden, z. B. `-v 1.15.1`. Nötig bei Git-Installationen, die als `canary` erscheinen |
| `-u` | Multicatyl entfernen und zurück zu Englisch wechseln |
| `-c` | Nur prüfen, ob der Patch passt (Signatur, `git apply --check`), nichts verändern. Exit-Code 2, wenn er nicht passt |
| `-s` | Status: Panel-Version, Sprache, installierter Patch, Anzahl Backups, verfügbare Patches |
| `-l` | Verfügbare Patches auflisten (ohne Panel, ohne root) |
| `-y` | Ohne 10 Sekunden Wartezeit starten |
| `-V` | Version des Installers anzeigen |
| `-h` | Hilfe anzeigen |

Voraussetzungen: root-Rechte, PHP 8.2/8.3, etwa 2 GB RAM (inkl. Swap) für den Build. Node.js ≥ 22, Yarn und Git installiert das Skript unter Debian/Ubuntu bei Bedarf selbst. Auf anderen Systemen musst du sie vorher selbst installieren.

Das Skript

- lädt den passenden Patch (`patches/<sprache>/v<version>.patch`, Quelle per `MULTICATYL_SOURCE` änderbar) und prüft seine Signatur: Die SHA-256-Prüfsumme muss in der signierten Liste `patches/de/SHA256SUMS` stehen (geprüft mit `gpgv` gegen den im Skript hinterlegten Schlüssel). Stimmt etwas nicht, bricht das Skript ohne Änderungen ab.
- prüft den Patch mit `git apply --check`. Ist er schon installiert, bricht es ohne Änderungen ab.
- sichert `app`, `resources`, `public`, `database`, `routes` und `config` nach `/var/backups/multicatyl/`.
- versetzt das Panel während der Arbeiten in den Wartungsmodus.
- wendet den Patch an und baut das Panel neu (`yarn install --frozen-lockfile`, `yarn run build:production`).
- setzt die Sprache auf Deutsch: `APP_LOCALE=de` in der `.env`, `settings::app:locale` in der Datenbank, und alle Benutzer mit Englisch werden auf Deutsch umgestellt.
- leert die Caches, setzt die Dateirechte und startet die Queue-Worker neu.

Schlägt der Build fehl, spielt das Skript das Backup automatisch zurück. Alle Ausgaben landen in `/var/log/multicatyl.log`.

## Neuen Patch erstellen

```bash
LANGUAGE=de ./scripts/startPatching.sh [version]   # z. B. v1.15.1, Standard: neuestes Release
# Übersetzungen in resources/, app/ usw. anpassen, .rej-Dateien einarbeiten und löschen
LANGUAGE=de ./scripts/createPatch.sh [version]     # Standard: Version aus startPatching.sh
```

`startPatching.sh` bricht ab, wenn du nicht auf `main` bist, dein Arbeitsverzeichnis nicht sauber ist oder der Branch `patches` bzw. der Tag `base` noch von einem früheren Lauf existiert. Anschließend wendet es den neuesten vorhandenen Patch an, der nicht neuer als die Zielversion ist.

`createPatch.sh` schreibt `patches/<sprache>/<version>.patch` (z. B. `patches/de/v1.15.1.patch`), wechselt zurück auf `main` und räumt den Patch-Modus auf. Danach trägst du die Version selbst in [`patches/README.md`](../patches/README.md) und in `KNOWN_PATCHES_<sprache>` in `install.sh` ein.

## Patches signieren

`createPatch.sh` erzeugt nach jedem neuen Patch `patches/<sprache>/SHA256SUMS` und signiert die Liste mit GPG (`patches/SHA256SUMS.asc`). Nur signieren (z. B. nach einer Korrektur an einem Patch):

```bash
MULTICATYL_SIGNING_KEY=<Fingerabdruck> ./scripts/createPatch.sh --sign
```

Der Workflow „Patches prüfen“ verhindert, dass unsignierte oder veränderte Patches nach `main` gelangen – der Installer würde sie sonst ablehnen.
