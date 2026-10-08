# Übersetzungen einreichen

Vielen Dank, dass du Multicatyl verbessern möchtest! Das gilt für Korrekturen an Deutsch genauso wie für eine
neue Sprache: Lege dafür einfach einen neuen Ordner `patches/<sprache>/` an und arbeite mit `LANGUAGE=<sprache>`.
So läuft ein Beitrag ab:

1. **Forke** das [Repository](https://github.com/hahn1315/Multicatyl) und klone deinen Fork.
2. **Arbeitsstand vorbereiten:** Das Skript lädt die passende Panel-Version und wendet den vorhandenen Patch an.
    ```shell
    LANGUAGE=de ./scripts/startPatching.sh 1.15.1
    ```
    Ohne Versionsangabe wird die neueste Panel-Version verwendet.
3. **Übersetzen:** Die Sprachdateien liegen in `resources/lang/<sprache>` (für Deutsch `de`), fest eingebaute Texte findest du in
   den Vorlagen unter `resources/`. Halte dich an die Richtlinien unten.
4. **Patch erstellen:**
    ```shell
    LANGUAGE=de ./scripts/createPatch.sh 1.15.1
    ```
    Der Patch landet unter `patches/<sprache>/v<version>.patch`.
5. **Pull Request** mit dem aktualisierten Patch eröffnen und kurz beschreiben, was du geändert hast.

!!! info "Signatur"
    Neue oder geänderte Patches müssen signiert werden, sonst lehnt der Installer sie ab. Das übernimmt der
    Maintainer beim Merge mit `./scripts/createPatch.sh --sign`. In deinem Pull Request darf der Workflow
    „Patches prüfen“ deshalb fehlschlagen.

## Richtlinien

- Wir sprechen die Nutzer mit **Du** an.
- Kurze, klare Texte – lieber natürlich als wortwörtlich übersetzt.
- Achte auf korrekte Rechtschreibung und einheitliche Begriffe.

### Glossar

| Englisch | Deutsch |
| --- | --- |
| Node | die Node |
| Allocation | Port-Zuweisung |
| Backup | Backup |
| Egg / Nest | Egg / Nest (unübersetzt) |
| Subuser | Unterbenutzer |
| Account | Konto |

Fragen? Eröffne gerne ein [Issue](https://github.com/hahn1315/Multicatyl/issues).
