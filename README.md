## Was ist GermanDactyl?

GermanDactyl ist die deutsche Übersetzung des [Pterodactyl Panels](https://pterodactyl.io/). Deutsch wird dabei als eigene Sprache (`resources/lang/de`) hinzugefügt, Englisch bleibt erhalten.

## Wie installiere ich das?

Ganz einfach:

```shell
curl -sSL https://install.germandactyl.de/ | sudo bash -s --
```

Der Installer erstellt vorher ein Backup, wendet den passenden Patch an und baut das Panel neu. Optionen (`-d`, `-v`, `-y`, `-u`, `-c`, `-s`, `-l`, `-h`) und Voraussetzungen findest du in der [Dokumentation](https://germandactyl.de/installation/).

## Unterstützte Versionen

Aktuelle Panel-Version: **v1.15.1**

| Pterodactyl Panel | GermanDactyl-Patch |
| --- | --- |
| 1.11.2 | v1.11.2 |
| 1.11.3 | v1.11.3 |
| 1.12.2 | v1.12.2 |
| 1.13.x, 1.14.x, 1.15.0 | kein eigener Patch – bitte auf 1.15.1 aktualisieren |
| 1.15.1 | v1.15.1 |

## Versionsverwaltung im Browser

Unter [germandactyl.de/manager/](https://germandactyl.de/manager/) (im Repo: [`docs/manager/index.html`](docs/manager/index.html)) findest du eine Web-Oberfläche, die dir

- zeigt, welche Panel-Version aktuell ist und welcher Patch dazu passt,
- den passenden Installationsbefehl mit allen Optionen zusammenbaut,
- deine eigenen Panels samt Patch-Stand lokal im Browser verwaltet,
- Prüfsummen, Signatur und Fehlerbehebung an einem Ort bündelt.

## Discord

Wenn du uns beim Übersetzen oder Umformulieren helfen möchtest, komm gerne [in unseren Discord](https://discord.gg/6R38NnTCct). Wie du Übersetzungen direkt per Pull Request einreichst, steht [in der Anleitung](https://germandactyl.de/guides/contribute/).

## Lizenz

Verbreitet unter der MIT-Lizenz. Siehe [`LICENSE`](LICENSE) für weitere Informationen.
