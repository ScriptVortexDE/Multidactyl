# Changelog

Alle wichtigen Änderungen an GermanDactyl (Installer, Patches, Dokumentation).

## 2.0.0 – 2026-10-08

### Neu

- **Versionsverwaltung im Browser** (`docs/manager/index.html`, erreichbar unter `/manager/`):
  Versionsmatrix Panel ↔ Patch, Befehls-Generator für alle Installer-Optionen, lokale Liste
  der eigenen Panels mit Patch-Stand, Signatur- und Prüfsummen-Infos, Fehlerbehebung.
- **Installer `-c`**: prüft nur, ob der Patch zum Panel passt (Signatur, `git apply --check`),
  verändert nichts. Exit-Code 2, wenn er nicht vollständig passt.
- **Installer `-s`**: zeigt Panel-Version, Sprache (`APP_LOCALE`), installierten Patch,
  Anzahl der Backups und verfügbare Patches.
- **Installer `-l`**: listet die verfügbaren Patches, ohne Panel und ohne root.
- **Installer `-V`**: gibt die Version des Installers aus.
- `CHANGELOG.md` (diese Datei).

### Behoben

- `README.md` enthielt den Inhalt 50-mal hintereinander (2,3 MB). Jetzt eine saubere Kopie.
- Installer: `.rej`-Dateien nach einer Teil-Installation wurden nur in `resources/`, `app/`
  und `public/` eingesammelt. Jetzt in allen erlaubten Ordnern (`database/`, `routes/`,
  `config/` eingeschlossen).
- Fehlerbehebung: Der Log-Pfad `/var/log/germandactyl.log` wurde fälschlich als „im Panel-Ordner“
  beschrieben.

### Dokumentation

- Optionen-Tabellen in Installation und `scripts/README.md` um `-c`, `-s`, `-l`, `-V` ergänzt.
- Neuer Tab „Nur prüfen“ in der Installationsanleitung.
- Fehlerbehebung: Abschnitt zu `-c` und `-s`.

## 1.15.1 – 2026-09-27

- Patch für Pterodactyl Panel v1.15.1.
- Signierte Prüfsummen (`patches/SHA256SUMS`, GPG-Schlüssel `2CB6 9766 DC1E 05E8 D805 D4C0 DF5A 303D 4015 76B8`).
- Installer prüft Signatur und Prüfsumme vor jeder Installation.
