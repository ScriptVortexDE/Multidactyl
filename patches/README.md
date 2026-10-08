# Patches

Jede Sprache hat einen eigenen Ordner `patches/<sprache>/` mit einem Patch je Panel-Version, einer Prüfsummenliste
`SHA256SUMS` und deren GPG-Signatur `SHA256SUMS.asc`. Jeder Patch übersetzt das Server- und das Adminpanel.

## Deutsch (`de`)

| Pterodactyl Panel | Patch |
| --- | --- |
| 1.11.2 | [v1.11.2](de/v1.11.2.patch) |
| 1.11.3 | [v1.11.3](de/v1.11.3.patch) |
| 1.12.2 | [v1.12.2](de/v1.12.2.patch) |
| 1.13.x, 1.14.x, 1.15.0 | kein eigener Patch – bitte das Panel auf 1.15.1 aktualisieren |
| 1.15.1 (aktuell) | [v1.15.1](de/v1.15.1.patch) |

Mit `-v <version>` kannst du im Installer einen anderen Patch erzwingen, mit `-L <sprache>` eine andere Sprache.
Ein Patch für eine andere Panel-Version passt meist nicht vollständig – das geschieht auf eigenes Risiko.

## Neue Patches oder Sprachen

```shell
LANGUAGE=de ./scripts/startPatching.sh [version]
# übersetzen …
LANGUAGE=de ./scripts/createPatch.sh [version]
```

Für eine neue Sprache nimmst du einfach einen neuen Code (`LANGUAGE=fr`); der Ordner wird angelegt. Die Anleitung
findest du unter [Übersetzungen einreichen](https://hahn1315.github.io/Multicatyl/guides/contribute/).

## Signatur

`multicatyl-signing-key.asc` ist der öffentliche Schlüssel, mit dem jede `SHA256SUMS` signiert ist. Der Installer
prüft Signatur und Prüfsumme vor jeder Installation und bricht sonst ab, ohne etwas zu verändern. Nach jeder
Änderung an einem Patch neu signieren:

```shell
LANGUAGE=de MULTICATYL_SIGNING_KEY=<Fingerabdruck> ./scripts/createPatch.sh --sign
```

Manuell prüfen (im Ordner `patches/de/`):

```shell
gpg --import ../multicatyl-signing-key.asc
gpg --verify SHA256SUMS.asc SHA256SUMS && sha256sum -c SHA256SUMS
```
