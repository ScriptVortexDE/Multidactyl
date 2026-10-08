# Multidactyl

Umfangreiches und einfaches Verwalten von Pterodactyl auf dem eigenen Server. Multidactyl übersetzt das [Pterodactyl Panel](https://pterodactyl.io/) in andere Sprachen – signierte Patches, ein Installer mit Backup und Rollback und eine Web-Oberfläche zur Versionsverwaltung. Englisch bleibt dabei immer erhalten.

Aktuell enthalten: **Deutsch** (`de`) für Panel **v1.15.1** sowie die älteren Versionen 1.11.2, 1.11.3 und 1.12.2. Weitere Sprachen kommen einfach als neuer Ordner `patches/<sprache>/` dazu.

## Installation

```shell
curl -fsSL https://raw.githubusercontent.com/ScriptVortexDE/Multidactyl/main/scripts/install.sh | sudo bash -s --
```

Der Installer erkennt die Panel-Version, lädt den passenden Patch, prüft Signatur und Prüfsumme, legt ein Backup an, wendet den Patch an, baut die Oberfläche neu und stellt die Sprache um. Schlägt der Build fehl, wird das Backup automatisch zurückgespielt.

| Option | Bedeutung |
| --- | --- |
| `-d <pfad>` | Pfad zum Panel (Standard `/var/www/pterodactyl`) |
| `-L <sprache>` | Sprache (Standard `de`) |
| `-v <version>` | Patch-Version erzwingen, z. B. bei `canary` |
| `-c` | nur prüfen, ob der Patch passt – verändert nichts |
| `-s` | Status: Panel-Version, Sprache, installierter Patch, Backups |
| `-l` | verfügbare Sprachen und Patches auflisten |
| `-u` | deinstallieren, zurück zu Englisch |
| `-y` | ohne Wartezeit starten |
| `-V` / `-h` | Version / Hilfe |

Alle Details, Voraussetzungen und die manuelle Installation stehen in der [Dokumentation](https://scriptvortexde.github.io/Multidactyl/).

## Unterstützte Versionen

| Pterodactyl Panel | Patch `de` |
| --- | --- |
| 1.11.2 | v1.11.2 |
| 1.11.3 | v1.11.3 |
| 1.12.2 | v1.12.2 |
| 1.13.x, 1.14.x, 1.15.0 | kein eigener Patch – bitte auf 1.15.1 aktualisieren |
| 1.15.1 (aktuell) | v1.15.1 |

## Versionsverwaltung im Browser

[`docs/manager/index.html`](docs/manager/index.html) (online unter `/manager/` der Dokumentation) zeigt

- welche Panel-Version aktuell ist und welcher Patch dazu passt,
- den fertigen Installationsbefehl für jede Option, Sprache und jeden Pfad,
- den Patch-Stand deiner eigenen Panels (lokal im Browser gespeichert),
- Prüfsummen, Signaturschlüssel und Fehlerbehebung an einem Ort.

## Sicherheit

Jeder Patch steht mit seiner SHA-256-Prüfsumme in `patches/<sprache>/SHA256SUMS`. Diese Liste ist mit GPG signiert (`SHA256SUMS.asc`), der öffentliche Schlüssel liegt in [`patches/multidactyl-signing-key.asc`](patches/multidactyl-signing-key.asc) und ist zusätzlich fest im Installer hinterlegt. Ein Patch, dessen Prüfsumme oder Signatur nicht stimmt, wird nicht angewendet.

## Eigene Patch-Quelle

Ohne Internet oder zum Testen eigener Patches kannst du einen lokalen Checkout als Quelle nutzen:

```shell
MULTIDACTYL_SOURCE=/opt/multidactyl sudo -E bash /opt/multidactyl/scripts/install.sh -c
```

## Mitmachen

Neue Panel-Version oder neue Sprache? Die Anleitung steht unter [Übersetzungen einreichen](https://scriptvortexde.github.io/Multidactyl/guides/contribute/). Fehler bitte als [Issue](https://github.com/ScriptVortexDE/Multidactyl/issues) melden.

## Lizenz und Herkunft

Apache-Lizenz 2.0, siehe [`LICENSE`](LICENSE). Die deutschen Übersetzungen in `patches/de/` basieren auf [GermanDactyl](https://github.com/pavl21/GermanDactyl) von Paul Schwarz und stehen unter MIT, siehe [`LICENSE-GermanDactyl`](LICENSE-GermanDactyl). Multidactyl ist davon unabhängig: eigene Patch-Quelle, eigener Signaturschlüssel, eigene Dokumentation.
