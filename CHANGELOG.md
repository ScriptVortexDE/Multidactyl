# Changelog

## 1.0.0 – 2026-10-08

Erste Version von **Multicatyl**, ein eigenständiges Projekt auf Basis der deutschen Übersetzung von
GermanDactyl (MIT-Lizenz). Alles, was an die alte Infrastruktur gebunden war, wurde ersetzt.

### Unabhängigkeit

- Patches, Prüfsummen und Installer werden direkt aus diesem Repository geladen
  (`raw.githubusercontent.com/<repo>/main/...`), keine fremden Domains mehr.
- Eigener GPG-Signaturschlüssel, öffentlich unter `patches/multicatyl-signing-key.asc` und fest im Installer.
- Eigene Dokumentation (MkDocs) ohne fremde Social-Links, Spenden-Links oder Domain.
- Die Patches selbst tragen jetzt Multicatyl-Hinweise und verlinken auf dieses Projekt.

### Neu gegenüber GermanDactyl

- **Mehrsprachig:** Patches liegen unter `patches/<sprache>/`, der Installer wählt mit `-L <sprache>` (Standard `de`).
- **Eigene Patch-Quelle:** `MULTICATYL_SOURCE` erlaubt einen lokalen Checkout oder eine andere URL-Basis, auch offline.
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
