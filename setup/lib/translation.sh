#!/bin/bash
# Pfad: lib/translation.sh
# Übersetzung des Panels mit Multidactyl: Auswahl der Panel-Version passend zu den verfügbaren
# Übersetzungs-Patches und Anwenden des Patches über den Multidactyl-Installer (scripts/install.sh).
# Der Installer prüft Signatur und Prüfsumme des Patches, legt ein Backup an, baut die Oberfläche
# (Node.js 22 + yarn) und stellt die Sprache um. Benötigt lib/common.sh.

GD_PATCH_LANG="${GD_PATCH_LANG:-de}"   # Sprache der Übersetzung (Ordner patches/<sprache>/ im Repository)
GD_PATCH_FALLBACK="1.15.1"            # Wird nur genutzt, wenn die Patch-Liste nicht abgerufen werden kann
GD_NODE_MAJOR="22"

gd_patch_source() {
    # Quelle der Patches für den Installer: lokaler Checkout (Entwicklung) oder das Repository
    if [ -n "${GD_LOCAL_DIR:-}" ] && [ -d "$GD_LOCAL_DIR/../patches" ]; then
        (cd "$GD_LOCAL_DIR/.." && pwd)
    else
        echo "$GD_RAW_ROOT"
    fi
}

gd_patch_exists() {
    # gd_patch_exists <version> -> wahr, wenn es einen Multidactyl-Patch in der gewählten Sprache gibt
    local src code
    src="$(gd_patch_source)"
    if [ -d "$src" ]; then
        [ -f "$src/patches/$GD_PATCH_LANG/v$1.patch" ]
        return
    fi
    code="$(curl -s -o /dev/null -L -w '%{http_code}' --max-time 15 "$src/patches/$GD_PATCH_LANG/v$1.patch")"
    [ "$code" = "200" ]
}

gd_patch_latest() {
    # Neueste Version, für die ein Patch existiert (aus dem Multidactyl-Repository ermittelt)
    local src list
    src="$(gd_patch_source)"
    if [ -d "$src" ]; then
        list="$(find "$src/patches/$GD_PATCH_LANG" -maxdepth 1 -name 'v*.patch' -printf '%f\n' 2>/dev/null \
            | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -n1)"
    else
        list="$(curl -fsS --max-time 15 "https://api.github.com/repos/$GD_REPO/contents/patches/$GD_PATCH_LANG?ref=$GD_BRANCH" 2>/dev/null \
            | grep -oE '"name": *"v[0-9]+\.[0-9]+\.[0-9]+\.patch"' \
            | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -n1)"
    fi
    echo "${list:-$GD_PATCH_FALLBACK}"
}

gd_choose_panel_version() {
    # Setzt GD_PANEL_VERSION und GD_APPLY_PATCH (true/false) – mit Dialog, falls kein passender Patch existiert.
    local latest patch_version choice
    latest="$(gd_latest_release pterodactyl/panel)"
    if [ -z "$latest" ]; then
        gd_msg "Fehler" "Die aktuelle Pterodactyl-Version konnte nicht ermittelt werden. Prüfe die Internetverbindung (github.com)." 9 70
        return 1
    fi

    if gd_patch_exists "$latest"; then
        GD_PANEL_VERSION="$latest"
        GD_APPLY_PATCH=true
        return 0
    fi

    patch_version="$(gd_patch_latest)"
    choice=$(whiptail --title "Multidactyl – Versionsauswahl" --menu "Die neueste Pterodactyl-Version ist v$latest. Für diese Version gibt es noch keine Übersetzung ($GD_PATCH_LANG).\n\nDie neueste übersetzte Version ist v$patch_version. Welche Version möchtest du installieren?" 18 78 2 \
        "1" "v$latest – aktuellste Version, Oberfläche auf Englisch" \
        "2" "v$patch_version – ältere Version, Oberfläche übersetzt ($GD_PATCH_LANG)" 3>&1 1>&2 2>&3) || return 1

    if [ "$choice" = "2" ]; then
        GD_PANEL_VERSION="$patch_version"
        GD_APPLY_PATCH=true
    else
        GD_PANEL_VERSION="$latest"
        GD_APPLY_PATCH=false
    fi
    return 0
}

gd_install_node() {
    # Node.js >= 22 sicherstellen (Distro-Paket, falls neu genug, sonst NodeSource-Repository) + yarn
    local current=0
    if command -v node >/dev/null 2>&1; then
        current="$(node -v | sed 's/^v//; s/\..*//')"
    fi
    if [ "$current" -lt "$GD_NODE_MAJOR" ]; then
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
            | gpg --dearmor --yes -o /etc/apt/keyrings/nodesource.gpg || return 1
        echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${GD_NODE_MAJOR}.x nodistro main" \
            > /etc/apt/sources.list.d/nodesource.list
        gd_apt update || return 1
        gd_apt install nodejs || return 1
    fi
    if ! command -v yarn >/dev/null 2>&1; then
        npm install -g yarn || return 1
    fi
    return 0
}

gd_build_swap_on() {
    # Der Frontend-Build braucht viel Arbeitsspeicher. Bei weniger als 3 GB RAM+Swap
    # wird für die Dauer des Builds eine temporäre Swap-Datei angelegt.
    local total
    total="$(LC_ALL=C free -m | awk '/^Mem:/{m=$2} /^Swap:/{s=$2} END{print m+s}')"
    GD_BUILD_SWAP=""
    if [ "${total:-0}" -lt 3072 ]; then
        GD_BUILD_SWAP="/swapfile-multidactyl-build"
        if fallocate -l 2G "$GD_BUILD_SWAP" 2>/dev/null || dd if=/dev/zero of="$GD_BUILD_SWAP" bs=1M count=2048 status=none; then
            chmod 600 "$GD_BUILD_SWAP"
            mkswap "$GD_BUILD_SWAP" >/dev/null && swapon "$GD_BUILD_SWAP" || { rm -f "$GD_BUILD_SWAP"; GD_BUILD_SWAP=""; }
        else
            GD_BUILD_SWAP=""
        fi
    fi
    return 0
}

gd_build_swap_off() {
    if [ -n "${GD_BUILD_SWAP:-}" ]; then
        swapoff "$GD_BUILD_SWAP" 2>/dev/null
        rm -f "$GD_BUILD_SWAP"
        GD_BUILD_SWAP=""
    fi
    return 0
}

gd_translation_installer() {
    # Holt den Multidactyl-Installer (scripts/install.sh) und gibt den Pfad aus
    local target="$GD_TMP/multidactyl-install.sh"
    if [ -n "${GD_LOCAL_DIR:-}" ] && [ -f "$GD_LOCAL_DIR/../scripts/install.sh" ]; then
        cp "$GD_LOCAL_DIR/../scripts/install.sh" "$target"
    else
        curl -fsSL "$GD_RAW_ROOT/scripts/install.sh" -o "$target" || return 1
    fi
    grep -q 'SIGNING_KEY_FPR' "$target" || { echo "Der Multidactyl-Installer ist unvollständig."; return 1; }
    echo "$target"
}

gd_patch_apply() {
    # gd_patch_apply <version> [panel-pfad] – wendet die Übersetzung über den Multidactyl-Installer an:
    # Signatur und Prüfsumme werden geprüft, Backup angelegt, Oberfläche gebaut, Sprache umgestellt.
    # Nicht passende Stellen (z. B. durch Blueprint veränderte Dateien) werden übersprungen (-f).
    local version="$1" dir="${2:-$PTERO_DIR}" installer rc=0
    installer="$(gd_translation_installer)" || return 1
    gd_build_swap_on
    MULTIDACTYL_SOURCE="$(gd_patch_source)" bash "$installer" -y -f -d "$dir" -L "$GD_PATCH_LANG" -v "$version" </dev/null || rc=$?
    gd_build_swap_off
    [ "$rc" -eq 0 ] || return "$rc"
    # node_modules wird nur behalten, wenn Blueprint es für Erweiterungen benötigt (spart sonst ~500 MB)
    [ -f "$dir/.blueprint/extensions/blueprint/private/db/is_installed" ] || rm -rf "$dir/node_modules"
    return 0
}

gd_panel_build() {
    # Frontend des Panels neu bauen (z. B. nach Blueprint), ohne die Übersetzung erneut anzuwenden
    local dir="${1:-$PTERO_DIR}" rc=0
    cd "$dir" || return 1
    # Ältere Build-Abhängigkeiten nutzen Hash-Verfahren, die OpenSSL 3 (Node >= 17) nur mit dem
    # Legacy-Provider erlaubt – sonst "error:0308010C:digital envelope routines::unsupported"
    export NODE_OPTIONS="--openssl-legacy-provider"
    gd_build_swap_on
    yarn install --frozen-lockfile --network-timeout 600000 || yarn install --network-timeout 600000 || rc=1
    [ $rc -eq 0 ] && { yarn run build:production || rc=1; }
    gd_build_swap_off
    [ $rc -eq 0 ] || return 1
    [ -f "$dir/.blueprint/extensions/blueprint/private/db/is_installed" ] || rm -rf node_modules
    php artisan view:clear
    php artisan optimize:clear
    chown -R www-data:www-data "$dir"
}

gd_translation_steps() {
    # gd_translation_steps <start-prozent> – Übersetzungs-Schritte innerhalb eines offenen Fortschrittsbalkens
    local p="${1:-85}"
    gd_step "$p" "Übersetzung: Node.js ${GD_NODE_MAJOR} und yarn werden vorbereitet..." gd_install_node
    gd_step $((p + 2)) "Übersetzung ($GD_PATCH_LANG, v$GD_PANEL_VERSION) wird geprüft, angewendet und die Oberfläche gebaut – das dauert einige Minuten..." gd_patch_apply "$GD_PANEL_VERSION"
    gd_conf_set GD_TRANSLATION "$GD_PANEL_VERSION"
    gd_conf_set GD_TRANSLATION_LANG "$GD_PATCH_LANG"
}
