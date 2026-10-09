#!/bin/bash
# Pfad: lib/panel2.sh
# Pterodactyl Panel 2.0 (Branch 2.0-develop) – Entwicklungsversion, Installation und Aktualisierung nach der
# offiziellen 2.0-Dokumentation (https://docs.pterodactyl.io/v2). Es gibt noch kein Release: Das Panel wird als
# ZIP des Branches geladen, die Oberfläche mit npm/Vite gebaut. Wings ist dasselbe wie bei 1.x.
# Benötigt lib/common.sh, lib/panel.sh (PHP, Pakete, nginx, Datenbank, Dienste) und lib/translation.sh (Node.js).

GD_PANEL2_BRANCH="2.0-develop"
GD_PANEL2_ZIP="https://github.com/pterodactyl/panel/archive/refs/heads/${GD_PANEL2_BRANCH}.zip"
GD_PANEL2_LABEL="2.0-develop"

gd_panel2_is_installed() {
    [ "$(gd_conf_get PANEL_MAJOR)" = "2" ]
}

gd_panel2_commit() {
    # Kurzer Commit-Hash des Branches, damit man den installierten Stand erkennen kann
    curl -fsSL --max-time 15 "https://api.github.com/repos/pterodactyl/panel/commits/${GD_PANEL2_BRANCH}" 2>/dev/null \
        | grep -m1 '"sha"' | sed -E 's/.*"sha": *"([0-9a-f]{7})[0-9a-f]*".*/\1/'
}

gd_panel2_mariadb_ok() {
    # 2.0 braucht MariaDB >= 10.11 (oder MySQL 8/9)
    local v
    v="$(mariadb --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -n1)"
    [ -n "$v" ] && gd_version_ge "$v" "10.11"
}

gd_panel2_mariadb_repo() {
    # Debian 11/12 und Ubuntu 22.04 liefern eine zu alte MariaDB: offizielles MariaDB-Repository (11.4 LTS) einrichten.
    # Debian 13 und Ubuntu 24.04 bringen bereits 11.x bzw. 10.11 mit.
    gd_os_detect
    if gd_panel2_mariadb_ok; then
        echo "MariaDB $(mariadb --version | grep -oE '[0-9]+\.[0-9]+' | head -n1) ist bereits installiert und neu genug."
        return 0
    fi
    case "$GD_OS_ID:$GD_OS_VERSION" in
        debian:11|debian:12|ubuntu:22.04)
            echo "MariaDB-Repository (11.4 LTS) wird eingerichtet (Distribution liefert < 10.11)."
            curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup \
                | bash -s -- --mariadb-server-version="mariadb-11.4" --skip-maxscale --skip-tools || return 1
            gd_apt update ;;
        *) ;;
    esac
    return 0
}

gd_panel2_download() {
    # Branch-ZIP laden und nach $PTERO_DIR entpacken (bei Updates: Dateien werden überschrieben, .env bleibt)
    local src="$GD_TMP/panel2"
    mkdir -p "$PTERO_DIR" "$src"
    curl -fL --retry 3 "$GD_PANEL2_ZIP" -o "$GD_TMP/panel2.zip" || return 1
    rm -rf "${src:?}"/*
    unzip -q -o "$GD_TMP/panel2.zip" -d "$src" || return 1
    cp -a "$src/panel-${GD_PANEL2_BRANCH}/." "$PTERO_DIR"/ || return 1
    rm -rf "$src" "$GD_TMP/panel2.zip"
    chmod -R 755 "$PTERO_DIR"/storage/* "$PTERO_DIR"/bootstrap/cache/
    GD_PANEL2_COMMIT="$(gd_panel2_commit)"
    gd_conf_set "${GD_CONF_PREFIX:-}PANEL2_COMMIT" "${GD_PANEL2_COMMIT:-unbekannt}"
    echo "Pterodactyl ${GD_PANEL2_LABEL} (Commit ${GD_PANEL2_COMMIT:-unbekannt}) entpackt."
}

gd_panel2_build() {
    # Oberfläche mit npm/Vite bauen (der Branch enthält keine gebauten Dateien)
    local rc=0
    cd "$PTERO_DIR" || return 1
    command -v npm >/dev/null 2>&1 || { echo "npm fehlt (Node.js 22 wird benötigt)."; return 1; }
    gd_build_swap_on
    npm ci --no-audit --no-fund || rc=1
    [ $rc -eq 0 ] && { npm run build:production || rc=1; }
    gd_build_swap_off
    [ $rc -eq 0 ] || return 1
    rm -rf "$PTERO_DIR/node_modules"
    return 0
}

gd_panel2_env_defaults() {
    # Rückfallebene, falls p:environment:setup in 2.0 andere Optionen hat: Werte direkt in die .env schreiben
    local domain="$1" email="$2" telemetry="$3"
    gd_env_set APP_ENV production
    gd_env_set APP_DEBUG false
    gd_env_set APP_URL "https://${domain}"
    gd_env_set APP_TIMEZONE "$GD_TIMEZONE"
    gd_env_set APP_SERVICE_AUTHOR "$email"
    gd_env_set APP_ENVIRONMENT_ONLY false
    gd_env_set CACHE_DRIVER redis
    gd_env_set SESSION_DRIVER redis
    gd_env_set QUEUE_CONNECTION redis
    gd_env_set REDIS_HOST 127.0.0.1
    gd_env_set REDIS_PASSWORD null
    gd_env_set REDIS_PORT 6379
    gd_env_set PTERODACTYL_TELEMETRY_ENABLED "$telemetry"
}

gd_panel2_configure() {
    # gd_panel2_configure <domain> <email> <db-passwort> <telemetrie true/false>
    local domain="$1" email="$2" dbpw="$3" telemetry="$4"
    cd "$PTERO_DIR" || return 1
    [ -f .env ] || cp .env.example .env
    php artisan key:generate --force || return 1
    if ! php artisan p:environment:setup --no-interaction \
        --author="$email" --url="https://${domain}" --timezone="$GD_TIMEZONE" \
        --cache=redis --session=redis --queue=redis \
        --redis-host=127.0.0.1 --redis-pass=null --redis-port=6379 \
        --settings-ui=true --telemetry="$telemetry"; then
        echo "p:environment:setup hat in dieser 2.0-Version andere Optionen – Werte werden direkt in die .env geschrieben."
        gd_panel2_env_defaults "$domain" "$email" "$telemetry"
    fi
    gd_env_set PTERODACTYL_TELEMETRY_ENABLED "$telemetry"
    if ! php artisan p:environment:database --no-interaction \
        --host=127.0.0.1 --port=3306 --database="$GD_PANEL_DB" \
        --username="$GD_PANEL_DB_USER" --password="$dbpw"; then
        echo "p:environment:database hat andere Optionen – Datenbankzugang wird direkt in die .env geschrieben."
        gd_env_set DB_CONNECTION mysql
        gd_env_set DB_HOST 127.0.0.1
        gd_env_set DB_PORT 3306
        gd_env_set DB_DATABASE "$GD_PANEL_DB"
        gd_env_set DB_USERNAME "$GD_PANEL_DB_USER"
        gd_env_set DB_PASSWORD "$dbpw"
    fi
    php artisan config:clear >/dev/null 2>&1 || true
    php artisan migrate --seed --force
}

gd_panel2_install_steps() {
    # Erwartet: GD_DOMAIN, GD_EMAIL, GD_ADMIN_USER, GD_ADMIN_PASSWORD, GD_DB_PASSWORD, GD_TELEMETRY
    GD_PANEL_MAJOR=2
    GD_PANEL_VERSION="$GD_PANEL2_LABEL"
    gd_conf_set "${GD_CONF_PREFIX:-}INSTALL_STATE" laeuft
    gd_conf_set "${GD_CONF_PREFIX:-}PANEL_MAJOR" 2
    gd_step 2  "Paketquellen werden aktualisiert..." gd_apt update
    gd_step 5  "PHP ${GD_PHP_VERSION}-Paketquelle wird eingerichtet..." gd_php_repo
    gd_step 9  "PHP ${GD_PHP_VERSION} wird installiert..." gd_php_packages
    gd_step 13 "MariaDB-Version wird geprüft (2.0 braucht 10.11 oder neuer)..." gd_panel2_mariadb_repo
    gd_step 17 "MariaDB, Redis, nginx und Certbot werden installiert..." gd_panel_packages
    gd_step 22 "Composer wird installiert..." gd_composer_install
    gd_step 24 "Node.js ${GD_NODE_MAJOR} wird eingerichtet..." gd_install_node
    gd_step 27 "Pterodactyl ${GD_PANEL2_LABEL} wird heruntergeladen..." gd_panel2_download
    gd_step 30 "Webserver wird für das SSL-Zertifikat vorbereitet..." gd_nginx_http_config "$GD_DOMAIN"
    gd_step 33 "SSL-Zertifikat wird bei Let's Encrypt angefordert..." gd_certbot_issue "$GD_DOMAIN" "$GD_EMAIL"
    gd_step 36 "Webserver wird mit SSL eingerichtet..." gd_nginx_ssl_config "$GD_DOMAIN"
    gd_step 37 "Automatische Zertifikatserneuerung wird eingerichtet..." gd_certbot_hook
    gd_step 39 "Datenbank für das Panel wird angelegt..." gd_panel_database "$GD_DB_PASSWORD"
    gd_step 42 "Composer-Abhängigkeiten werden installiert (dauert etwas)..." gd_panel_composer
    gd_step 48 "Oberfläche wird gebaut (npm/Vite, dauert einige Minuten)..." gd_panel2_build
    gd_step 56 "Panel wird konfiguriert und die Datenbank eingerichtet..." gd_panel2_configure "$GD_DOMAIN" "$GD_EMAIL" "$GD_DB_PASSWORD" "$GD_TELEMETRY"
    gd_step 60 "Administrator-Konto wird angelegt..." gd_panel_admin "$GD_EMAIL" "$GD_ADMIN_USER" "$GD_ADMIN_PASSWORD"
    if [ -z "${GD_DEV_INSTANCE:-}" ] && declare -F gd_pending_credentials_save >/dev/null; then gd_pending_credentials_save; fi
    gd_step 62 "Berechtigungen werden gesetzt..." gd_panel_permissions
    gd_step 64 "Cronjob und Hintergrunddienst (Queue) werden eingerichtet..." gd_panel_services
    gd_step 70 "Panel wird auf Erreichbarkeit geprüft..." gd_panel_healthcheck "$GD_DOMAIN"

    gd_conf_set "${GD_CONF_PREFIX:-}PANEL_DOMAIN" "$GD_DOMAIN"
    gd_conf_set "${GD_CONF_PREFIX:-}PANEL_EMAIL" "$GD_EMAIL"
    gd_conf_set "${GD_CONF_PREFIX:-}PANEL_VERSION" "$GD_PANEL2_LABEL"
}

gd_panel2_update_steps() {
    # Neuesten Stand des Branches einspielen (Dateien überschreiben, .env bleibt), bauen, migrieren
    gd_step 10 "Panel wird in den Wartungsmodus versetzt..." bash -c "cd '$PTERO_DIR' && (php artisan down || true)"
    gd_step 15 "Node.js ${GD_NODE_MAJOR} wird geprüft..." gd_install_node
    gd_step 20 "Pterodactyl ${GD_PANEL2_LABEL} wird heruntergeladen..." gd_panel2_download
    gd_step 35 "Composer-Abhängigkeiten werden installiert..." gd_panel_composer
    gd_step 45 "Oberfläche wird gebaut (npm/Vite)..." gd_panel2_build
    gd_step 70 "Zwischenspeicher werden geleert..." bash -c "cd '$PTERO_DIR' && php artisan optimize:clear"
    gd_step 75 "Datenbank wird aktualisiert..." bash -c "cd '$PTERO_DIR' && php artisan migrate --force"
    gd_step 85 "Berechtigungen werden gesetzt..." gd_panel_permissions
    gd_step 90 "Hintergrunddienste werden neu gestartet..." bash -c "cd '$PTERO_DIR' && php artisan queue:restart; systemctl restart $GD_QUEUE_SERVICE php${GD_PHP_VERSION}-fpm"
    gd_step 95 "Panel wird wieder freigegeben..." bash -c "cd '$PTERO_DIR' && php artisan up"
    gd_conf_set "${GD_CONF_PREFIX:-}PANEL_VERSION" "$GD_PANEL2_LABEL"
}

gd_panel2_update() {
    gd_yesno "↑ Pterodactyl 2.0 aktualisieren" "Installiert: ${GD_PANEL2_LABEL} (Commit $(gd_conf_get "${GD_CONF_PREFIX:-}PANEL2_COMMIT"))\nZiel: neuester Stand des Branches ${GD_PANEL2_BRANCH}\n\nEntwicklungsversion: Der neue Stand kann Fehler enthalten. Das Panel ist während der Aktualisierung einige Minuten nicht erreichbar.\n\nEmpfehlung: Erstelle vorher ein Backup über die Backup-Verwaltung.\n\nMöchtest du fortfahren?" 17 78 || return 1
    gd_gauge_open "↑ Pterodactyl 2.0 wird aktualisiert" "Aktualisierung wird vorbereitet..."
    gd_panel2_update_steps
    gd_progress 100 "Aktualisierung abgeschlossen."
    gd_gauge_close
    gd_msg "✔ Aktualisierung abgeschlossen" "Pterodactyl ${GD_PANEL2_LABEL} wurde auf Commit $(gd_conf_get "${GD_CONF_PREFIX:-}PANEL2_COMMIT") aktualisiert.\n\nFalls dein Browser noch die alte Oberfläche anzeigt, lade die Seite mit Strg + F5 neu." 11 70
}

gd_panel2_warning_dialog() {
    # Hinweis vor der Installation der Entwicklungsversion. Rückgabe 1 = abgebrochen
    gd_warn_colors_on
    local ok=0
    gd_yesno "Pterodactyl 2.0 – Entwicklungsversion" "Pterodactyl 2.0 ist noch nicht veröffentlicht. Installiert wird der aktuelle Stand des Branches ${GD_PANEL2_BRANCH}, der sich täglich ändert und Fehler enthalten kann.\n\nNur zum Testen – nicht für ein Panel mit echten Kunden.\n\nUnterschiede zu 1.x in diesem Setup:\n- keine Übersetzung (2.0 bringt ein eigenes Sprachsystem mit, Deutsch folgt)\n- kein Blueprint\n- Update = neuester Branch-Stand\n\nWings ist dasselbe wie bei 1.x und wird wie gewohnt eingerichtet.\n\nMöchtest du fortfahren?" 22 78 || ok=1
    gd_warn_colors_off
    return $ok
}
