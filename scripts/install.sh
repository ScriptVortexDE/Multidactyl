#!/usr/bin/env bash
#
# Multidactyl – Installationsskript
#
# Übersetzt ein Pterodactyl-Panel in eine andere Sprache (Standard: Deutsch)
# bzw. macht das mit -u wieder rückgängig. Gedacht für den Aufruf über:
#
#   curl -fsSL https://raw.githubusercontent.com/ScriptVortexDE/Multidactyl/main/scripts/install.sh | sudo bash -s -- [Optionen]
#
# Die Patches liegen im Repository unter patches/<sprache>/v<version>.patch.
# Mit der Umgebungsvariable MULTIDACTYL_SOURCE kann eine andere Quelle gewählt
# werden: ein lokaler Ordner (z. B. ein Checkout) oder eine andere URL-Basis.
#
# Neben Installation (Standard) und Deinstallation (-u) gibt es drei Modi, die
# nichts am Panel verändern: -c prüft nur, ob der Patch passt, -s zeigt den
# Status des Panels, -l listet die verfügbaren Patches.
#
# Da stdin dabei die Pipe ist, liest das Skript Rückfragen von /dev/tty.
#
# Ablauf der Installation:
#   Panel finden → Patch laden und prüfen → Abhängigkeiten → Backup →
#   Wartungsmodus → Patch anwenden → Panel bauen → Sprache auf Deutsch →
#   Caches leeren, Rechte setzen → Wartungsmodus beenden
#
# Schlägt ein Schritt nach dem Patchen fehl, wird das Backup automatisch
# zurückgespielt.

set -Eeuo pipefail

# ---------------------------------------------------------------------------
# Einstellungen
# ---------------------------------------------------------------------------

readonly SCRIPT_VERSION="1.0.0"
readonly PROJECT_NAME=Multidactyl
readonly DEFAULT_PATH=/var/www/pterodactyl
readonly DEFAULT_LANG=de

# Quelle der Patches: GitHub-Repository (Standard) oder MULTIDACTYL_SOURCE
# (lokaler Ordner mit patches/<sprache>/ oder eine URL-Basis mit derselben Struktur).
readonly REPO="${MULTIDACTYL_REPO:-ScriptVortexDE/Multidactyl}"
readonly BRANCH="${MULTIDACTYL_BRANCH:-main}"
readonly SOURCE="${MULTIDACTYL_SOURCE:-https://raw.githubusercontent.com/$REPO/$BRANCH}"
readonly PATCH_LIST_API="https://api.github.com/repos/$REPO/contents/patches"

# Öffentlicher Schlüssel, mit dem patches/SHA256SUMS signiert wird.
# SIGNING_KEY_FPR: Fingerabdruck (40 Hex-Zeichen, ohne Leerzeichen)
# SIGNING_KEY_B64: gpg --export <Fingerabdruck> | base64 -w0
readonly SIGNING_KEY_FPR="DCE980AE97BDA4501FE7D8AF949F1BD17BC59545"
readonly SIGNING_KEY_B64="mDMEasgKgBYJKwYBBAHaRw8BAQdANweeSlaeqyOuTiISx+iaT5FvWY3imvSJDSi23Z2bHAi0QE11bHRpZGFjdHlsIFBhdGNoIFNpZ25pbmcgPG11bHRpZGFjdHlsQHVzZXJzLm5vcmVwbHkuZ2l0aHViLmNvbT6IkAQTFgoAOBYhBNzpgK6XvaRQH+fYr5SfG9F7xZVFBQJqyAqAAhsDBQsJCAcCBhUKCQgLAgQWAgMBAh4BAheAAAoJEJSfG9F7xZVFMYcA+QFUqs64DgSkL/y8YY6Khge+gSqRZuX5Vy1eZSRhdDXGAP0dwvyMn4BOHP5c9WfilzQESkio0LBd49DObS6y63I4BA=="
readonly PANEL_RELEASES=https://github.com/pterodactyl/panel/releases/download
readonly BACKUP_ROOT=/var/backups/multidactyl
readonly MIN_NODE_MAJOR=22
readonly MIN_MEMORY_MB=2048

# Fallback, falls die GitHub-API nicht erreichbar ist (je Sprache).
readonly KNOWN_LANGS="de"
readonly KNOWN_PATCHES_de="1.11.2 1.11.3 1.12.2 1.15.1"

# Verzeichnisse, die gesichert werden (sofern vorhanden).
readonly BACKUP_DIRS=(app resources public database routes config)

# Pfade, die ein Patch verändern darf. Alles andere wird übersprungen.
readonly ALLOWED_DIRS=(app resources public database routes config)
readonly ALLOWED_PATCH_PATHS='^(app|resources|public|database|routes|config)/'

# Gemeinsame Optionen für "git apply" (Standardkontext, nur erlaubte Pfade).
APPLY_OPTS=(--ignore-whitespace --ignore-space-change)
for _dir in "${ALLOWED_DIRS[@]}"; do
    APPLY_OPTS+=("--include=$_dir/*")
done
unset _dir

# ---------------------------------------------------------------------------
# Laufzeitvariablen
# ---------------------------------------------------------------------------

USER_PATH=""
FORCE_VERSION=""
PATCH_LANG=$DEFAULT_LANG
MODE=install
ASSUME_YES=0

PTERODACTYL_PATH=""
PANEL_VERSION=""   # Version laut config/app.php
VERSION=""         # Version des Patches (Standard: PANEL_VERSION, sonst -v)
INSTALLED_PATCH="" # Kopie des installierten Patches (für -u)
LOG=""
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE=""
PATCH_FILE=""
TMP_DIR=""
MAINTENANCE=0
ROLLBACK_NEEDED=0
CREATED_FILES=()
USE_APT=0

# ---------------------------------------------------------------------------
# Ausgabe
# ---------------------------------------------------------------------------

if [ -t 1 ]; then
    RED=$'\033[1;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    BLUE=$'\033[1;34m'
    NORMAL=$'\033[0m'
else
    RED="" GREEN="" YELLOW="" BLUE="" NORMAL=""
fi

send_success() { printf '%s✓ %s%s\n' "$GREEN" "$1" "$NORMAL"; }
send_info()    { printf '%sℹ %s%s\n' "$BLUE" "$1" "$NORMAL"; }
send_warn()    { printf '%s⚠ %s%s\n' "$YELLOW" "$1" "$NORMAL" >&2; }

send_error() {
    printf '%s✗ %s%s\n' "$RED" "$1" "$NORMAL" >&2
    exit 1
}

show_help() {
    cat <<EOF
Multidactyl – Übersetzungen für das Pterodactyl-Panel

Verwendung:
  curl -fsSL https://raw.githubusercontent.com/ScriptVortexDE/Multidactyl/main/scripts/install.sh | sudo bash -s -- [Optionen]
  sudo bash install.sh [Optionen]

Optionen:
  -d <pfad>     Pfad zum Panel (Standard: $DEFAULT_PATH)
  -L <sprache>  Sprache des Patches (Standard: $DEFAULT_LANG)
  -v <version>  Patch für diese Panel-Version verwenden, z. B. -v 1.15.1
                (nötig bei Git-Installationen, die als "canary" erscheinen)
  -u            Multidactyl deinstallieren und zurück zu Englisch wechseln
  -c            Nur prüfen, ob der Patch zum Panel passt (verändert nichts)
  -s            Status anzeigen: Panel-Version, Sprache, installierter Patch
  -l            Verfügbare Sprachen und Patches auflisten (kein Panel, kein root)
  -y            Ohne 10 Sekunden Wartezeit starten
  -V            Version dieses Skripts anzeigen
  -h            Diese Hilfe anzeigen

Umgebung:
  MULTIDACTYL_SOURCE  Alternative Patch-Quelle: lokaler Ordner oder URL-Basis
                     (Standard: $SOURCE)

Bekannte Patches (de): $KNOWN_PATCHES_de
Log-Datei: /var/log/multidactyl.log
Backups:   $BACKUP_ROOT
EOF
}

# Schreibt die Ausgabe eines Befehls ins Log.
run_logged() {
    "$@" >>"$LOG" 2>&1
}

# Kann das Skript Rückfragen stellen? (Bei "curl | bash" ist stdin die Pipe.)
has_tty() {
    (exec </dev/tty) 2>/dev/null
}

# Ja/Nein-Rückfrage, Standard ist Nein. Ohne Terminal immer Nein.
ask_yes_no() {
    local answer=""
    if ! has_tty; then
        send_warn "Keine Rückfrage möglich (kein Terminal). Es wird \"Nein\" angenommen."
        return 1
    fi
    printf '%s? %s [j/N] %s' "$YELLOW" "$1" "$NORMAL" >/dev/tty
    read -r answer </dev/tty || return 1
    [[ $answer =~ ^[jJyY] ]]
}

# Zeigt die letzten Zeilen des Logs an (bei Fehlern).
show_log_tail() {
    send_warn "Die letzten 30 Zeilen aus $LOG:"
    tail -n 30 "$LOG" >&2 || true
}

# ---------------------------------------------------------------------------
# Aufräumen, Rollback, Fehlerbehandlung
# ---------------------------------------------------------------------------

on_error() {
    local code=$? line=$1
    printf '%s✗ Unerwarteter Fehler in Zeile %s (Exit-Code %s).%s\n' "$RED" "$line" "$code" "$NORMAL" >&2
    [ -z "$LOG" ] || printf 'Unerwarteter Fehler in Zeile %s (Exit-Code %s)\n' "$line" "$code" >>"$LOG"
    exit "$code"
}

cleanup() {
    local code=$?
    set +e
    trap - ERR

    if [ "$ROLLBACK_NEEDED" = 1 ]; then
        rollback
    fi

    if [ "$MAINTENANCE" = 1 ]; then
        if (cd "$PTERODACTYL_PATH" && php artisan up >>"$LOG" 2>&1); then
            send_info "Der Wartungsmodus wurde beendet."
        else
            send_warn "Der Wartungsmodus konnte nicht beendet werden. Führe \"php artisan up\" im Panel-Ordner aus."
        fi
    fi

    [ -z "$TMP_DIR" ] || rm -rf "$TMP_DIR"

    if [ "$code" -ne 0 ] && [ -n "$LOG" ]; then
        printf '%sℹ Details findest du im Log: %s%s\n' "$BLUE" "$LOG" "$NORMAL" >&2
    fi
    exit "$code"
}

rollback() {
    ROLLBACK_NEEDED=0
    send_warn "Die Änderungen werden rückgängig gemacht …"

    if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
        send_warn "Kein Backup gefunden. Bitte stelle das Panel manuell wieder her."
        return
    fi

    # Vom Patch neu angelegte Dateien entfernen (z. B. resources/lang/de).
    local file
    for file in "${CREATED_FILES[@]}"; do
        rm -f "$PTERODACTYL_PATH/$file"
    done
    if [ "$MODE" = install ]; then
        rm -rf "$PTERODACTYL_PATH/resources/lang/$PATCH_LANG"
    fi

    if tar -xzf "$BACKUP_FILE" -C "$PTERODACTYL_PATH" >>"$LOG" 2>&1; then
        send_success "Das Backup wurde zurückgespielt. Dein Panel ist wieder im vorherigen Zustand."
    else
        send_warn "Das Backup konnte nicht zurückgespielt werden. Du findest es unter $BACKUP_FILE."
    fi
}

trap 'on_error $LINENO' ERR
trap cleanup EXIT
trap 'exit 130' INT TERM

# ---------------------------------------------------------------------------
# Optionen
# ---------------------------------------------------------------------------

parse_options() {
    local opt
    while getopts ":d:L:v:ucslyVh" opt; do
        case "$opt" in
            d) USER_PATH=$OPTARG ;;
            L) PATCH_LANG=$OPTARG ;;
            v) FORCE_VERSION=${OPTARG#v} ;;
            u) MODE=uninstall ;;
            c) MODE=check ;;
            s) MODE=status ;;
            l) MODE=list ;;
            y) ASSUME_YES=1 ;;
            V) printf 'Multidactyl-Installer %s\n' "$SCRIPT_VERSION"; exit 0 ;;
            h) show_help; exit 0 ;;
            :)
                show_help >&2
                send_error "Die Option -$OPTARG braucht einen Wert."
                ;;
            *)
                show_help >&2
                send_error "Unbekannte Option: -$OPTARG"
                ;;
        esac
    done
    shift $((OPTIND - 1))
    if [ $# -gt 0 ]; then
        show_help >&2
        send_error "Unbekanntes Argument: $1"
    fi
    [[ $PATCH_LANG =~ ^[a-z]{2}(_[A-Z]{2})?$ ]] \
        || send_error "Ungültiger Sprachcode \"$PATCH_LANG\". Erwartet wird z. B. de oder pt_BR."
}

# Holt eine Datei aus der Patch-Quelle (Ordner oder URL) nach <ziel>.
# Gibt bei URLs den HTTP-Status in FETCH_CODE zurück, bei Ordnern 200/404.
FETCH_CODE=""
fetch_source() {
    local rel=$1 dest=$2
    if [ -d "$SOURCE" ]; then
        if [ -f "$SOURCE/$rel" ]; then
            cp "$SOURCE/$rel" "$dest" && FETCH_CODE=200 || FETCH_CODE=000
        else
            FETCH_CODE=404
        fi
    else
        FETCH_CODE=$(curl -fsSL --proto '=https' --proto-redir '=https' \
            -o "$dest" -w '%{http_code}' "$SOURCE/$rel" 2>>"$LOG") || true
    fi
    [ "$FETCH_CODE" = 200 ]
}

# Liefert die Fallback-Liste bekannter Patches für $PATCH_LANG.
known_patches() {
    local var="KNOWN_PATCHES_${PATCH_LANG//-/_}"
    printf '%s\n' "${!var:-}"
}

# ---------------------------------------------------------------------------
# Panel finden
# ---------------------------------------------------------------------------

load_pterodactyl_path() {
    local path=${USER_PATH:-$DEFAULT_PATH}

    if [ -z "$USER_PATH" ]; then
        send_info "Kein Pfad angegeben. Das Panel wird unter $BLUE$DEFAULT_PATH$NORMAL gesucht (anderer Pfad: -d <pfad>)."
    fi

    [ -d "$path" ] || send_error "Der Ordner $path existiert nicht oder ist nicht lesbar."

    PTERODACTYL_PATH=$(cd "$path" && pwd -P)

    if [ ! -f "$PTERODACTYL_PATH/artisan" ] || [ ! -f "$PTERODACTYL_PATH/config/app.php" ]; then
        send_error "Unter $PTERODACTYL_PATH wurde kein Pterodactyl-Panel gefunden. Gib den richtigen Pfad mit -d <pfad> an."
    fi

    PANEL_VERSION=$(sed -n "s/.*'version' => '\([^']*\)'.*/\1/p" "$PTERODACTYL_PATH/config/app.php" | head -n 1)
    VERSION=$PANEL_VERSION
    INSTALLED_PATCH="$BACKUP_ROOT/installiert-$PATCH_LANG-$PANEL_VERSION.patch"
    [ -n "$PANEL_VERSION" ] || send_error "Die Panel-Version konnte nicht aus config/app.php gelesen werden."

    local label="v$PANEL_VERSION"
    [ "$PANEL_VERSION" != canary ] || label=canary
    send_success "Pterodactyl-Panel $BLUE$label$GREEN unter $BLUE$PTERODACTYL_PATH$GREEN gefunden."

    if [ -n "$FORCE_VERSION" ] && [ "$FORCE_VERSION" != "$VERSION" ]; then
        send_warn "Du erzwingst die Version ${BLUE}v$FORCE_VERSION$YELLOW, obwohl das Panel $label meldet. Das geschieht auf eigenes Risiko."
        VERSION=$FORCE_VERSION
    fi
}

init_log() {
    LOG=/var/log/multidactyl.log
    if ! { touch "$LOG" && [ -w "$LOG" ]; } 2>/dev/null; then
        LOG="$PTERODACTYL_PATH/multidactyl.debug.log"
        touch "$LOG" || send_error "Die Log-Datei $LOG kann nicht angelegt werden."
    fi
    printf '\n===== Multidactyl – %s – %s – Panel %s (%s), Patch %s/%s =====\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "$MODE" "$PTERODACTYL_PATH" "$PANEL_VERSION" "$PATCH_LANG" "$VERSION" >>"$LOG"
}

# ---------------------------------------------------------------------------
# Patches
# ---------------------------------------------------------------------------

list_available_patches() {
    local list=""
    if [ -d "$SOURCE" ]; then
        list=$(find "$SOURCE/patches/$PATCH_LANG" -maxdepth 1 -name 'v*.patch' -printf '%f\n' 2>/dev/null \
            | sed -n 's/^v\([0-9][0-9.]*\)\.patch$/\1/p' | sort -V | paste -sd ' ' -) || true
    else
        list=$(curl -fsSL --max-time 10 "$PATCH_LIST_API/$PATCH_LANG" 2>/dev/null \
            | sed -n 's/.*"name": *"v\([0-9][0-9.]*\)\.patch".*/\1/p' \
            | sort -V | paste -sd ' ' -) || true
    fi
    printf '%s\n' "${list:-$(known_patches)}"
}

# Verfügbare Sprachen (Unterordner von patches/).
list_available_langs() {
    local list=""
    if [ -d "$SOURCE" ]; then
        list=$(find "$SOURCE/patches" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort | paste -sd ' ' -) || true
    else
        list=$(curl -fsSL --max-time 10 "$PATCH_LIST_API" 2>/dev/null \
            | tr ',' '\n' | sed -n 's/.*"path": *"patches\/\([a-z_A-Z]*\)".*/\1/p' | sort -u | paste -sd ' ' -) || true
    fi
    printf '%s\n' "${list:-$KNOWN_LANGS}"
}

no_patch_error() {
    send_error "$1
  Verfügbare Patches ($PATCH_LANG): $(list_available_patches)
  Mit ${BLUE}-v <version>$RED kannst du einen bestimmten Patch wählen, z. B.: ${BLUE}-v 1.15.1$RED
  Mit ${BLUE}-L <sprache>$RED eine andere Sprache, verfügbar: $(list_available_langs)
  Am besten aktualisierst du dein Panel auf eine Version, für die es einen Patch gibt."
}

# Lädt den Patch für $VERSION nach $PATCH_FILE. Den HTTP-Status merkt sich
# DOWNLOAD_CODE ("invalid", wenn die Datei kein Patch ist).
DOWNLOAD_CODE=""
download_patch() {
    PATCH_FILE="$TMP_DIR/multidactyl-$PATCH_LANG-v$VERSION.patch"

    fetch_source "patches/$PATCH_LANG/v$VERSION.patch" "$PATCH_FILE" || true
    DOWNLOAD_CODE=$FETCH_CODE

    [ "$DOWNLOAD_CODE" = 200 ] || return 1
    if ! grep -q '^diff --git ' "$PATCH_FILE"; then
        DOWNLOAD_CODE=invalid
        return 1
    fi
    if ! verify_patch; then
        DOWNLOAD_CODE=unverified
        return 1
    fi
}

ensure_gpgv() {
    command -v gpgv >/dev/null 2>&1 && return 0
    detect_distro
    require_apt "gpgv (zum Prüfen der Signatur)"
    send_info "gpgv wird installiert …"
    apt_install gpgv
}

# Prüft den Patch in $PATCH_FILE gegen die signierte Prüfsummenliste.
# Bei einem Fehler steht der Grund in VERIFY_ERROR.
VERIFY_ERROR=""
verify_patch() {
    local dir="$TMP_DIR/signature" name expected actual

    if [[ ! $SIGNING_KEY_FPR =~ ^[0-9A-F]{40}$ ]] || [[ $SIGNING_KEY_B64 == __* ]]; then
        VERIFY_ERROR="In diesem Installer ist kein Signaturschlüssel hinterlegt."
        return 1
    fi
    ensure_gpgv

    # Prüfsummenliste und Signatur nur einmal pro Lauf laden und prüfen.
    if [ ! -f "$dir/verified" ]; then
        rm -rf "$dir"
        mkdir -p "$dir/gnupg"
        chmod 700 "$dir/gnupg"

        if ! fetch_source "patches/$PATCH_LANG/SHA256SUMS" "$dir/SHA256SUMS" \
            || ! fetch_source "patches/$PATCH_LANG/SHA256SUMS.asc" "$dir/SHA256SUMS.asc"; then
            VERIFY_ERROR="Die signierte Prüfsummenliste konnte nicht geladen werden."
            return 1
        fi

        if ! printf '%s' "$SIGNING_KEY_B64" | base64 -d >"$dir/key.gpg" 2>/dev/null; then
            VERIFY_ERROR="Der hinterlegte Signaturschlüssel ist beschädigt."
            return 1
        fi

        printf -- '--- gpgv ---\n' >>"$LOG"
        if ! gpgv --homedir "$dir/gnupg" --keyring "$dir/key.gpg" --status-fd 3 \
                "$dir/SHA256SUMS.asc" "$dir/SHA256SUMS" 3>"$dir/status" >>"$LOG" 2>&1 \
            || ! grep -Eq "^\[GNUPG:\] VALIDSIG .*\b$SIGNING_KEY_FPR\b" "$dir/status"; then
            VERIFY_ERROR="Die Signatur der Prüfsummenliste ist ungültig."
            return 1
        fi
        touch "$dir/verified"
    fi

    name="v$VERSION.patch"
    expected=$(awk -v f="$name" '$2 == f || $2 == "*" f { print $1; exit }' "$dir/SHA256SUMS")
    if [ -z "$expected" ]; then
        VERIFY_ERROR="Für $name gibt es keine signierte Prüfsumme."
        return 1
    fi
    actual=$(sha256sum "$PATCH_FILE" | cut -d' ' -f1)
    if [ "$actual" != "$expected" ]; then
        VERIFY_ERROR="Die Prüfsumme von $name stimmt nicht mit der signierten Liste überein."
        return 1
    fi
    printf 'Signatur und Prüfsumme von %s sind gültig (%s).\n' "$name" "$actual" >>"$LOG"
}

find_patch() {
    if [ "$VERSION" = canary ]; then
        no_patch_error "Dein Panel meldet die Version \"canary\" (Installation aus Git). Welcher Patch passt, kann nicht automatisch erkannt werden."
    fi

    if ! download_patch; then
        case "$DOWNLOAD_CODE" in
            404)     no_patch_error "Für die Panel-Version ${BLUE}v$VERSION$RED gibt es noch keinen Multidactyl-Patch (Sprache: $PATCH_LANG)." ;;
            000|"")  send_error "Die Patch-Quelle $SOURCE ist nicht erreichbar. Prüfe deine Internetverbindung." ;;
            invalid) send_error "Die heruntergeladene Datei ist kein gültiger Patch." ;;
            unverified) send_error "$VERIFY_ERROR
  Der Patch wird aus Sicherheitsgründen nicht angewendet. Versuche es später erneut oder melde das Problem." ;;
            *)       send_error "Der Patch konnte nicht geladen werden (HTTP-Status $DOWNLOAD_CODE). Versuche es später erneut." ;;
        esac
    fi

    send_success "Patch ${BLUE}$PATCH_LANG/v$VERSION$GREEN geladen, Signatur und Prüfsumme sind gültig."
}

# Prüft die Pfade im Patch und merkt sich neu angelegte Dateien.
inspect_patch() {
    local paths bad
    paths=$(git apply --numstat "$PATCH_FILE" 2>>"$LOG" | cut -f3-) \
        || send_error "Der Patch kann nicht gelesen werden."

    if printf '%s\n' "$paths" | grep -Eq '(^|/)\.\.(/|$)|^/'; then
        send_error "Der Patch enthält ungültige Pfade und wird aus Sicherheitsgründen nicht angewendet."
    fi

    bad=$(printf '%s\n' "$paths" | grep -Ev "$ALLOWED_PATCH_PATHS" | grep -v '^$' || true)
    if [ -n "$bad" ]; then
        printf 'Übersprungene Pfade:\n%s\n' "$bad" >>"$LOG"
        send_warn "Der Patch enthält Dateien außerhalb von app/, resources/, public/ usw. Diese werden übersprungen."
    fi

    mapfile -t CREATED_FILES < <(git apply "${APPLY_OPTS[@]}" --summary "$PATCH_FILE" 2>/dev/null \
        | sed -n 's/^ create mode [0-7]* //p')
}

# Zeigt die Dateien an, bei denen "git apply --check" gescheitert ist.
show_failed_files() {
    local file
    sed -n -e 's/^error: patch failed: \(.*\):[0-9]*$/\1/p' \
        -e 's/^error: \(.*\): \(patch does not apply\|No such file or directory\|already exists in working directory\)$/\1/p' "$1" \
        | sort -u | while read -r file; do
            printf '%s  ✗ %s%s\n' "$RED" "$file" "$NORMAL" >&2
        done
}

# ---------------------------------------------------------------------------
# Abhängigkeiten
# ---------------------------------------------------------------------------

detect_distro() {
    local id="" like=""
    if [ -r /etc/os-release ]; then
        # Nicht per "source" einlesen: os-release definiert u. a. VERSION.
        id=$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"')
        like=$(sed -n 's/^ID_LIKE=//p' /etc/os-release | tr -d '"')
    fi
    if [[ " $id $like " =~ \ (debian|ubuntu)\  ]] && command -v apt-get >/dev/null 2>&1; then
        USE_APT=1
    fi
}

require_apt() {
    [ "$USE_APT" = 1 ] && return 0
    send_error "$1 fehlt und kann nur unter Debian/Ubuntu automatisch installiert werden.
  Bitte installiere es selbst und starte das Skript danach erneut."
}

APT_UPDATED=0
apt_install() {
    if [ "$APT_UPDATED" = 0 ]; then
        run_logged apt-get update || send_error "\"apt-get update\" ist fehlgeschlagen."
        APT_UPDATED=1
    fi
    DEBIAN_FRONTEND=noninteractive run_logged apt-get install -y "$@" \
        || send_error "Die Installation von $* ist fehlgeschlagen."
}

node_major() {
    local v
    v=$(node -v 2>/dev/null) || { echo 0; return; }
    v=${v#v}
    echo "${v%%.*}"
}

ensure_git() {
    # "git apply" funktioniert auch außerhalb eines Git-Repositorys, git wird
    # aber trotzdem gebraucht.
    command -v git >/dev/null 2>&1 && return
    require_apt "Git"
    send_info "Git wird installiert …"
    apt_install git
    command -v git >/dev/null 2>&1 || send_error "Git konnte nicht installiert werden."
    send_success "Git wurde installiert."
}

ensure_php() {
    command -v php >/dev/null 2>&1 || send_error "PHP wurde nicht gefunden. Das Panel braucht PHP 8.2 oder 8.3."
    local v
    v=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || true)
    case "$v" in
        8.2|8.3) ;;
        *) send_warn "Gefundene PHP-Version: ${v:-unbekannt}. Das Panel unterstützt offiziell PHP 8.2 und 8.3." ;;
    esac
}

ensure_node() {
    local major
    major=$(node_major)
    if [ "$major" -ge "$MIN_NODE_MAJOR" ]; then
        return
    fi

    if [ "$major" -eq 0 ]; then
        send_info "Node.js wurde nicht gefunden."
    else
        send_info "Node.js $major ist zu alt, das Panel braucht mindestens Node.js $MIN_NODE_MAJOR."
    fi
    require_apt "Node.js $MIN_NODE_MAJOR"

    send_info "Node.js $MIN_NODE_MAJOR wird über NodeSource installiert. Das kann etwa eine Minute dauern …"
    if ! curl -fsSL "https://deb.nodesource.com/setup_${MIN_NODE_MAJOR}.x" 2>>"$LOG" | bash - >>"$LOG" 2>&1; then
        send_error "Die NodeSource-Paketquelle konnte nicht eingerichtet werden."
    fi
    APT_UPDATED=1
    apt_install nodejs
    hash -r

    major=$(node_major)
    [ "$major" -ge "$MIN_NODE_MAJOR" ] \
        || send_error "Node.js $MIN_NODE_MAJOR konnte nicht installiert werden (gefunden: ${major})."
    send_success "Node.js $(node -v) wurde installiert."
}

ensure_yarn() {
    command -v yarn >/dev/null 2>&1 && return
    send_info "Yarn wird installiert …"
    if command -v npm >/dev/null 2>&1; then
        run_logged npm install -g yarn || true
        hash -r
    fi
    if ! command -v yarn >/dev/null 2>&1 && command -v corepack >/dev/null 2>&1; then
        run_logged corepack enable || true
        hash -r
    fi
    yarn --version >/dev/null 2>&1 || send_error "Yarn konnte nicht installiert werden. Installiere es mit \"npm install -g yarn\"."
    send_success "Yarn $(yarn --version) wurde installiert."
}

check_memory() {
    local mb
    mb=$(awk '/^(MemTotal|SwapTotal):/ { s += $2 } END { print int(s / 1024) }' /proc/meminfo 2>/dev/null || echo 0)
    if [ "$mb" -gt 0 ] && [ "$mb" -lt "$MIN_MEMORY_MB" ]; then
        send_warn "Dein Server hat nur ${mb} MB Arbeitsspeicher (inkl. Swap). Der Build braucht etwa 2 GB – lege bei Problemen Swap an."
    fi
}

install_build_deps() {
    ensure_php
    ensure_node
    ensure_yarn
    check_memory
}

# ---------------------------------------------------------------------------
# Backup, Wartungsmodus, Build
# ---------------------------------------------------------------------------

create_backup() {
    local dirs=() dir
    for dir in "${BACKUP_DIRS[@]}"; do
        if [ -e "$PTERODACTYL_PATH/$dir" ]; then
            dirs+=("$dir")
        fi
    done

    install -d -m 700 "$BACKUP_ROOT"
    BACKUP_FILE="$BACKUP_ROOT/panel-$PANEL_VERSION-$STAMP.tar.gz"

    send_info "Backup wird erstellt: $BACKUP_FILE"
    run_logged tar -czf "$BACKUP_FILE" -C "$PTERODACTYL_PATH" "${dirs[@]}" \
        || send_error "Das Backup konnte nicht erstellt werden (genug Speicherplatz frei?)."
    send_success "Backup erstellt."
}

maintenance_down() {
    if run_logged php artisan down; then
        MAINTENANCE=1
        send_info "Das Panel ist während der Arbeiten im Wartungsmodus."
    else
        send_warn "Der Wartungsmodus konnte nicht aktiviert werden. Es geht trotzdem weiter."
    fi
}

build_panel() {
    send_info "Das Panel wird neu gebaut. Das dauert einige Minuten …"
    printf -- '--- yarn install ---\n' >>"$LOG"
    if ! run_logged yarn install --frozen-lockfile; then
        show_log_tail
        send_error "\"yarn install\" ist fehlgeschlagen."
    fi
    printf -- '--- yarn run build:production ---\n' >>"$LOG"
    if ! run_logged yarn run build:production; then
        # Ältere Panel-Versionen (Webpack 4, z. B. v1.11.x) brauchen unter Node >= 17 den OpenSSL-Legacy-Provider.
        if grep -q "ERR_OSSL_EVP_UNSUPPORTED" "$LOG"; then
            send_warn "Build mit OpenSSL-Legacy-Modus wird erneut versucht (ältere Panel-Version) …"
            printf -- '--- yarn run build:production (NODE_OPTIONS=--openssl-legacy-provider) ---\n' >>"$LOG"
            if ! NODE_OPTIONS=--openssl-legacy-provider run_logged yarn run build:production; then
                show_log_tail
                send_error "Der Build des Panels ist fehlgeschlagen."
            fi
        else
            show_log_tail
            send_error "Der Build des Panels ist fehlgeschlagen."
        fi
    fi
    send_success "Das Panel wurde gebaut."
}

finish_panel() {
    run_logged php artisan view:clear || send_warn "\"php artisan view:clear\" ist fehlgeschlagen."
    run_logged php artisan config:clear || send_warn "\"php artisan config:clear\" ist fehlgeschlagen."

    # Besitzer numerisch (uid:gid) ermitteln: artisan → storage → Webserver-Benutzer.
    local owner user
    owner=$(stat -c '%u:%g' "$PTERODACTYL_PATH/artisan")
    if [[ $owner == 0:* ]]; then
        owner=$(stat -c '%u:%g' "$PTERODACTYL_PATH/storage" 2>/dev/null || echo "0:0")
    fi
    if [[ $owner == 0:* ]]; then
        for user in www-data nginx apache; do
            if id -u "$user" >/dev/null 2>&1; then
                owner="$(id -u "$user"):$(id -g "$user")"
                break
            fi
        done
    fi

    if [[ $owner == 0:* ]]; then
        send_warn "Kein Webserver-Benutzer gefunden. Prüfe die Dateirechte des Panels selbst."
    elif run_logged chown -R "$owner" "$PTERODACTYL_PATH"; then
        send_success "Dateirechte gesetzt ($(stat -c '%U:%G' "$PTERODACTYL_PATH/artisan"))."
    else
        send_warn "Die Dateirechte konnten nicht auf $owner gesetzt werden."
    fi

    run_logged php artisan queue:restart || send_warn "Die Queue-Worker konnten nicht neu gestartet werden."
}

# ---------------------------------------------------------------------------
# Sprache
# ---------------------------------------------------------------------------

# set_locale <neu> <alt>: setzt APP_LOCALE, den Panel-Standard in der Datenbank
# und stellt alle Benutzer mit Sprache <alt> auf <neu> um.
set_locale() {
    local new=$1 old=$2 env="$PTERODACTYL_PATH/.env" count

    if [ -f "$env" ]; then
        if grep -q '^APP_LOCALE=' "$env"; then
            sed -i "s/^APP_LOCALE=.*/APP_LOCALE=$new/" "$env"
        else
            if [ -n "$(tail -c 1 "$env")" ]; then
                echo >>"$env"
            fi
            echo "APP_LOCALE=$new" >>"$env"
        fi
        send_success "APP_LOCALE=$new in der .env gesetzt."
    else
        send_warn "Keine .env gefunden. Setze APP_LOCALE=$new bitte selbst."
    fi

    # shellcheck disable=SC2016 # PHP-Code, $ ist hier gewollt
    local php_code='
        require "vendor/autoload.php";
        $app = require "bootstrap/app.php";
        $app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
        Illuminate\Support\Facades\DB::table("settings")->updateOrInsert(
            ["key" => "settings::app:locale"], ["value" => $argv[1]]
        );
        echo Illuminate\Support\Facades\DB::table("users")
            ->where("language", $argv[2])->update(["language" => $argv[1]]), PHP_EOL;
    '

    if count=$(cd "$PTERODACTYL_PATH" && php -r "$php_code" -- "$new" "$old" 2>>"$LOG" | tail -n 1) \
        && [[ $count =~ ^[0-9]+$ ]]; then
        send_success "Standardsprache des Panels auf \"$new\" gesetzt, $count Benutzer von \"$old\" auf \"$new\" umgestellt."
    else
        send_warn "Die Sprache konnte nicht in der Datenbank umgestellt werden. Benutzer können sie in ihren Kontoeinstellungen selbst ändern."
    fi
}

# ---------------------------------------------------------------------------
# Installation
# ---------------------------------------------------------------------------

countdown() {
    if [ "$ASSUME_YES" = 1 ]; then
        return
    fi
    send_info "$1 startet in 10 Sekunden. Drücke Strg+C, um abzubrechen (überspringen mit -y)."
    sleep 10
}

apply_patch() {
    local check_log="$TMP_DIR/check.log" use_reject=0

    if git apply "${APPLY_OPTS[@]}" --reverse --check "$PATCH_FILE" >/dev/null 2>&1; then
        send_success "Multidactyl ($PATCH_LANG) ist für v$VERSION bereits installiert. Es gibt nichts zu tun."
        send_info "Zum Entfernen: Skript mit -u starten."
        exit 0
    fi

    if ! git apply "${APPLY_OPTS[@]}" --check "$PATCH_FILE" >"$check_log" 2>&1; then
        cat "$check_log" >>"$LOG"
        send_warn "Der Patch passt nicht vollständig zu deinem Panel. Betroffene Dateien:"
        show_failed_files "$check_log"
        if [ -d "$PTERODACTYL_PATH/resources/lang/$PATCH_LANG" ]; then
            send_warn "Multidactyl scheint bereits (teilweise) installiert zu sein. Entferne es zuerst mit -u."
        else
            send_warn "Möglicherweise hat ein Addon oder Theme diese Dateien verändert."
        fi
        if ask_yes_no "Soll der Patch trotzdem teilweise angewendet werden? Nicht passende Stellen bleiben englisch."; then
            use_reject=1
        else
            send_error "Abgebrochen. An deinem Panel wurde nichts verändert."
        fi
    fi

    create_backup
    cp "$PATCH_FILE" "$INSTALLED_PATCH"
    maintenance_down

    ROLLBACK_NEEDED=1
    send_info "Der Patch wird angewendet …"
    printf -- '--- git apply ---\n' >>"$LOG"
    if [ "$use_reject" = 1 ]; then
        run_logged git apply "${APPLY_OPTS[@]}" --reject "$PATCH_FILE" || true
        handle_rejects
    else
        run_logged git apply "${APPLY_OPTS[@]}" "$PATCH_FILE" \
            || send_error "Der Patch konnte nicht angewendet werden."
    fi
    send_success "Der Patch wurde angewendet."
}

handle_rejects() {
    local rej_dir="$BACKUP_ROOT/rejects-v$VERSION-$STAMP" file count=0
    while IFS= read -r -d '' file; do
        file=${file#./}
        printf '%s  ✗ %s konnte nicht (vollständig) übersetzt werden.%s\n' "$RED" "${file%.rej}" "$NORMAL" >&2
        install -d "$rej_dir/$(dirname "$file")"
        mv "$file" "$rej_dir/$file"
        count=$((count + 1))
    done < <(find "${ALLOWED_DIRS[@]}" -name '*.rej' -print0 2>/dev/null)

    if [ "$count" -gt 0 ]; then
        send_warn "$count Datei(en) wurden nicht vollständig gepatcht. Die abgelehnten Stellen liegen unter $rej_dir."
    fi
}

do_install() {
    find_patch
    countdown "Die Installation"

    detect_distro
    ensure_git
    install_build_deps

    cd "$PTERODACTYL_PATH"
    inspect_patch
    apply_patch
    build_panel
    ROLLBACK_NEEDED=0

    set_locale "$PATCH_LANG" en
    finish_panel

    send_success "Multidactyl ($PATCH_LANG) wurde installiert. Viel Spaß mit deinem übersetzten Panel! :)"
    send_info "Backup: $BACKUP_FILE"
}

# ---------------------------------------------------------------------------
# Deinstallation
# ---------------------------------------------------------------------------

# Versucht, das Release-Tarball derselben Version zu laden.
download_release() {
    local tarball="$TMP_DIR/panel.tar.gz" code
    if [ "$PANEL_VERSION" = canary ]; then
        return 1
    fi
    code=$(curl -fsSL --proto '=https' --proto-redir '=https' \
        -o "$tarball" -w '%{http_code}' "$PANEL_RELEASES/v$PANEL_VERSION/panel.tar.gz" 2>>"$LOG") || true
    [ "$code" = 200 ] && tar -tzf "$tarball" >/dev/null 2>&1
}

latest_backup() {
    find "$BACKUP_ROOT" -maxdepth 1 -name "panel-$PANEL_VERSION-*.tar.gz" 2>/dev/null | sort | tail -n 1
}

do_uninstall() {
    local method="" backup_src=""

    detect_distro
    ensure_git
    cd "$PTERODACTYL_PATH"

    # Patch besorgen: gespeicherte Kopie oder frisch herunterladen.
    if [ -f "$INSTALLED_PATCH" ]; then
        PATCH_FILE=$INSTALLED_PATCH
    elif [ "$VERSION" != canary ] && download_patch; then
        :
    else
        PATCH_FILE=""
    fi
    if [ -n "$PATCH_FILE" ]; then
        mapfile -t CREATED_FILES < <(git apply "${APPLY_OPTS[@]}" --summary "$PATCH_FILE" 2>/dev/null \
            | sed -n 's/^ create mode [0-7]* //p')
    fi

    # Nicht installiert? Dann nur die Sprache zurückstellen.
    if [ -n "$PATCH_FILE" ] && [ ! -d "resources/lang/$PATCH_LANG" ] \
        && git apply "${APPLY_OPTS[@]}" --check "$PATCH_FILE" >/dev/null 2>&1; then
        send_info "Multidactyl ist in diesem Panel nicht installiert. Es wird nur die Sprache auf Englisch zurückgestellt."
        set_locale en "$PATCH_LANG"
        run_logged php artisan config:clear || true
        exit 0
    fi

    # 1. Patch sauber rückwärts anwenden (erhält Addons).
    if [ -n "$PATCH_FILE" ] && git apply "${APPLY_OPTS[@]}" --reverse --check "$PATCH_FILE" >/dev/null 2>&1; then
        method=reverse
        send_info "Multidactyl wird entfernt, indem der Patch rückgängig gemacht wird."
    # 2. Originaldateien aus dem Release-Tarball.
    elif download_release; then
        method=tarball
        send_info "Multidactyl wird entfernt, indem die Originaldateien von v$PANEL_VERSION neu entpackt werden."
        send_warn "Änderungen durch Addons oder Themes in app/ und resources/ gehen dabei verloren."
    # 3. Backup von der Installation.
    elif backup_src=$(latest_backup) && [ -n "$backup_src" ]; then
        method=backup
        send_info "Multidactyl wird entfernt, indem das Backup $backup_src zurückgespielt wird."
    else
        send_error "Multidactyl kann nicht automatisch entfernt werden: Weder der Patch noch das Release-Archiv von v$PANEL_VERSION noch ein Backup sind verfügbar.
  Lade das Panel-Release deiner Version neu herunter (siehe https://pterodactyl.io/panel/1.0/updating.html)."
    fi

    countdown "Die Deinstallation"
    if [ "$method" = reverse ]; then
        install_build_deps
    fi

    create_backup
    maintenance_down
    ROLLBACK_NEEDED=1

    case "$method" in
        reverse)
            run_logged git apply "${APPLY_OPTS[@]}" --reverse "$PATCH_FILE" \
                || send_error "Der Patch konnte nicht rückgängig gemacht werden."
            ;;
        tarball)
            # Vorkompilierte Assets aus dem Release übernehmen – kein Build nötig.
            run_logged tar -xzf "$TMP_DIR/panel.tar.gz" -C "$PTERODACTYL_PATH" \
                app resources database routes public/themes public/assets \
                || send_error "Das Release-Archiv konnte nicht entpackt werden."
            ;;
        backup)
            run_logged tar -xzf "$backup_src" -C "$PTERODACTYL_PATH" \
                || send_error "Das Backup konnte nicht zurückgespielt werden."
            ;;
    esac

    local file
    for file in "${CREATED_FILES[@]}"; do
        rm -f "$PTERODACTYL_PATH/$file"
    done
    rm -rf "$PTERODACTYL_PATH/resources/lang/$PATCH_LANG"
    send_success "Die Sprachdateien ($PATCH_LANG) wurden entfernt."

    # Nur nach dem Rückwärts-Patch müssen die Assets neu gebaut werden; Tarball
    # und Backup enthalten bereits fertige englische Assets.
    if [ "$method" = reverse ]; then
        build_panel
    fi
    ROLLBACK_NEEDED=0

    set_locale en "$PATCH_LANG"
    finish_panel
    rm -f "$INSTALLED_PATCH"

    send_success "Multidactyl wurde entfernt. Dein Panel ist wieder auf Englisch."
    send_info "Backup des deutschen Stands: $BACKUP_FILE"
}

# ---------------------------------------------------------------------------
# Prüfen, Status, Auflisten (verändern nichts am Panel)
# ---------------------------------------------------------------------------

# -c: Patch laden, Signatur prüfen und mit "git apply --check" testen.
# Exit-Code 0: passt (oder schon installiert), 2: passt nicht vollständig.
do_check() {
    local check_log="$TMP_DIR/check.log"

    find_patch
    command -v git >/dev/null 2>&1 \
        || send_error "Git wird für die Prüfung gebraucht. Installiere es mit \"apt-get install git\"."

    cd "$PTERODACTYL_PATH"
    inspect_patch

    if git apply "${APPLY_OPTS[@]}" --reverse --check "$PATCH_FILE" >/dev/null 2>&1; then
        send_success "Multidactyl v$VERSION ist bereits vollständig installiert."
        return 0
    fi
    if git apply "${APPLY_OPTS[@]}" --check "$PATCH_FILE" >"$check_log" 2>&1; then
        send_success "Der Patch v$VERSION passt vollständig zu deinem Panel. Es wurde nichts verändert."
        send_info "Zum Installieren das Skript ohne -c starten."
        return 0
    fi

    cat "$check_log" >>"$LOG"
    send_warn "Der Patch v$VERSION passt nicht vollständig zu deinem Panel. Betroffene Dateien:"
    show_failed_files "$check_log"
    if [ -d "resources/lang/$PATCH_LANG" ]; then
        send_warn "Multidactyl scheint bereits (teilweise) installiert zu sein. Entferne es zuerst mit -u."
    else
        send_warn "Möglicherweise hat ein Addon oder Theme diese Dateien verändert."
    fi
    exit 2
}

# -s: Zustand des Panels ausgeben, ohne etwas zu laden oder zu verändern.
do_status() {
    local env="$PTERODACTYL_PATH/.env" locale="" state backups patches

    if [ -f "$env" ]; then
        locale=$(sed -n 's/^APP_LOCALE=//p' "$env" | tr -d "\"'" | head -n 1)
    fi

    if [ ! -d "$PTERODACTYL_PATH/resources/lang/de" ]; then
        state="nicht installiert"
    elif [ -f "$INSTALLED_PATCH" ] && command -v git >/dev/null 2>&1 \
        && (cd "$PTERODACTYL_PATH" && git apply "${APPLY_OPTS[@]}" --reverse --check "$INSTALLED_PATCH" >/dev/null 2>&1); then
        state="installiert ($PATCH_LANG, Patch v$PANEL_VERSION, vollständig)"
    elif [ -f "$INSTALLED_PATCH" ]; then
        state="installiert ($PATCH_LANG, Patch v$PANEL_VERSION, Dateien wurden seitdem verändert)"
    else
        state="installiert (Sprachdateien $PATCH_LANG vorhanden, Patch-Version unbekannt)"
    fi

    backups=0
    if [ -d "$BACKUP_ROOT" ]; then
        backups=$(find "$BACKUP_ROOT" -maxdepth 1 -name 'panel-*.tar.gz' | wc -l)
    fi
    patches=$(list_available_patches)

    printf 'Installer:          %s\n' "$SCRIPT_VERSION"
    printf 'Panel-Pfad:         %s\n' "$PTERODACTYL_PATH"
    printf 'Panel-Version:      %s\n' "$PANEL_VERSION"
    printf 'Multidactyl:       %s\n' "$state"
    printf 'APP_LOCALE:         %s\n' "${locale:-nicht gesetzt}"
    printf 'Backups:            %s unter %s\n' "$backups" "$BACKUP_ROOT"
    printf 'Sprache:            %s\n' "$PATCH_LANG"
    printf 'Verfügbare Patches: %s\n' "$patches"
    printf 'Patch-Quelle:       %s\n' "$SOURCE"

    if [ "$PANEL_VERSION" = canary ]; then
        send_warn "Das Panel meldet \"canary\" (Git-Installation). Gib die Version beim Installieren mit -v an."
    elif [[ " $patches " == *" $PANEL_VERSION "* ]]; then
        send_success "Für v$PANEL_VERSION gibt es einen passenden Patch ($PATCH_LANG)."
    else
        send_warn "Für v$PANEL_VERSION gibt es keinen eigenen Patch. Aktualisiere das Panel auf eine unterstützte Version."
    fi
}

# -l: verfügbare Patches auflisten (GitHub-API, sonst die eingebaute Liste).
do_list() {
    local lang langs
    [ -d "$SOURCE" ] || command -v curl >/dev/null 2>&1 || send_error "curl wurde nicht gefunden. Bitte installiere es zuerst."
    langs=$(list_available_langs)
    printf 'Patch-Quelle: %s\n' "$SOURCE"
    printf 'Signatur:     Schlüssel %s\n\n' "$SIGNING_KEY_FPR"
    for lang in $langs; do
        PATCH_LANG=$lang
        printf '%-6s %s\n' "$lang:" "$(list_available_patches)"
    done
    printf '\nPatch-Dateien: %s/patches/<sprache>/v<version>.patch\n' "$SOURCE"
}

# ---------------------------------------------------------------------------
# Start
# ---------------------------------------------------------------------------

main() {
    parse_options "$@"

    if [ "$MODE" = list ]; then
        do_list
        exit 0
    fi

    [ "$EUID" -eq 0 ] || send_error "Bitte führe das Skript als root aus (z. B. mit sudo)."
    command -v curl >/dev/null 2>&1 || send_error "curl wurde nicht gefunden. Bitte installiere es zuerst."
    command -v tar >/dev/null 2>&1 || send_error "tar wurde nicht gefunden. Bitte installiere es zuerst."

    load_pterodactyl_path

    if [ "$MODE" = status ]; then
        LOG=/dev/null
        do_status
        exit 0
    fi

    init_log
    TMP_DIR=$(mktemp -d) || send_error "Es konnte kein temporärer Ordner angelegt werden."

    # Keine übergeordneten Git-Repositorys berücksichtigen (z. B. /var/www).
    GIT_CEILING_DIRECTORIES=$(dirname "$PTERODACTYL_PATH")
    export GIT_CEILING_DIRECTORIES

    case "$MODE" in
        uninstall) do_uninstall ;;
        check)     do_check ;;
        *)         do_install ;;
    esac
}

main "$@"
