# Multidactyl Setup

Mit Multidactyl Setup richtest du ein Pterodactyl Panel samt Wings (oder ein Pelican Panel) über eine Textoberfläche
in einer SSH-Sitzung ein. Du brauchst nur einen Linux-Server und eine Domain, deren A-Eintrag auf den Server zeigt.
Ist Pterodactyl bereits installiert, öffnet sich stattdessen die Verwaltung.

!!! info "Voraussetzungen"
    - Debian 11, 12 oder 13 bzw. Ubuntu 22.04, 24.04 oder 26.04 (amd64 oder arm64)
    - Root-Rechte
    - Eine Domain, deren A-Eintrag auf diesen Server zeigt (bei Cloudflare: Proxy aus, „DNS only“)
    - Ein frisch aufgesetztes System, auf dem Port 80 und 443 frei sind

## Start

```shell
sudo bash -c "$(curl -sSL https://raw.githubusercontent.com/ScriptVortexDE/Multidactyl/main/setup/installer.sh)"
```

Nach der Installation startest du die Verwaltung jederzeit mit `multidactyl` oder kurz `mdt`.

## Was eingerichtet wird

- **Pakete:** PHP 8.3 (packages.sury.org), MariaDB, Redis, nginx, Composer, Certbot
- **Panel:** Pterodactyl Panel mit Cronjob und Queue-Dienst, SSL über Let's Encrypt mit automatischer Erneuerung
- **Übersetzung:** Gibt es für die neueste Panel-Version einen Multidactyl-Patch, wird er automatisch angewendet
  (mit Signaturprüfung, Backup und Rollback). Sonst wählst du: neueste Version auf Englisch oder neueste übersetzte Version.
- **Wings (optional):** Docker, Wings, automatisch angelegte Node, Konfiguration, Portbereich für Gameserver
- **Absicherung (wählbar):** UFW-Firewall mit SSH-Schutz, fail2ban, automatische Sicherheitsupdates, tägliche Backups (restic)
- **Admin-Konto:** wird automatisch angelegt, die Zugangsdaten bekommst du am Ende angezeigt
- **Pelican (Beta):** alternativ Pelican Panel und Pelican Wings

## Verwaltung

Der Bereich Verwaltung bietet Problembehandlung mit automatischer Reparatur, Panel- und Wings-Updates, Ports freigeben,
Blueprint, phpMyAdmin, Backups und Wiederherstellung, Database-Host, SSH-Loginseite, Swap, Zertifikatserneuerung und
die Deinstallation.

## Bereits mit GermanDactyl Setup installiert?

Multidactyl Setup erkennt solche Server und übernimmt die Konfiguration aus `/etc/germandactyl` beim ersten Start.
Danach nutzt du einfach `mdt`.

!!! tip "Lokaler Checkout"
    Zum Testen oder ohne Internet kannst du das Repository klonen und das Setup direkt starten; Bibliotheken und
    Patches werden dann aus dem Checkout geladen:

    ```shell
    git clone https://github.com/ScriptVortexDE/Multidactyl.git /opt/multidactyl
    sudo bash /opt/multidactyl/setup/installer.sh
    ```

## Bekannte Probleme, die hier bereits behoben sind

| Problem | Ursache | Status |
| --- | --- | --- |
| `"server_tokens" directive is duplicate` beim SSL-Schritt | Direktive im `http`-Kontext, Debian 13 setzt sie bereits | behoben |
| Warnung `the "listen ... http2" directive is deprecated` | nginx ≥ 1.25.1 | behoben (`http2 on;`) |

Startet das Skript bei dir nicht, eröffne bitte ein [Issue](https://github.com/ScriptVortexDE/Multidactyl/issues)
und hänge das Log aus `/var/log/multidactyl-setup/` an.
