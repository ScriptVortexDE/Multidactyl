#!/bin/bash
# Pfad: lib/instance.sh
# Dev-Instanz: Ein zweites, getrenntes Pterodactyl 2.0 (2.0-develop) neben dem bestehenden Panel – eigener Ordner,
# eigene Datenbank, eigene Domain, eigene nginx-Konfiguration und eigener Queue-Dienst. Das Hauptpanel bleibt
# unberührt. Wings gehört weiterhin zum Hauptpanel (ein Wings kann nur mit einem Panel verbunden sein).
# Benötigt lib/common.sh, lib/panel.sh, lib/panel2.sh, lib/translation.sh.

GD_DEV_DIR="/var/www/pterodactyl-dev"
GD_DEV_DB="panel_dev"
GD_DEV_DB_USER="pterodactyl_dev"
GD_DEV_NGINX_CONF="pterodactyl-dev.conf"
GD_DEV_QUEUE="pteroq-dev"
GD_DEV_PREFIX="DEV_"

gd_dev_installed() {
    [ -f "$GD_DEV_DIR/artisan" ]
}

gd_dev_context() {
    # Schaltet alle instanzabhängigen Variablen auf die Dev-Instanz um. Nur in einer Subshell verwenden,
    # damit das Hauptpanel danach wieder gilt: ( gd_dev_context; ... )
    PTERO_DIR="$GD_DEV_DIR"
    GD_PANEL_DB="$GD_DEV_DB"
    GD_PANEL_DB_USER="$GD_DEV_DB_USER"
    GD_NGINX_CONF="$GD_DEV_NGINX_CONF"
    GD_NGINX_LOG="pterodactyl-dev"
    GD_QUEUE_SERVICE="$GD_DEV_QUEUE"
    GD_CONF_PREFIX="$GD_DEV_PREFIX"
    GD_DEV_INSTANCE=1
    GD_PANEL_MAJOR=2
}

gd_dev_status_text() {
    if gd_dev_installed; then
        echo "Installiert: ja – https://$(gd_conf_get DEV_PANEL_DOMAIN) (2.0-develop, Commit $(gd_conf_get DEV_PANEL2_COMMIT))\nOrdner: $GD_DEV_DIR   Datenbank: $GD_DEV_DB   Dienst: $GD_DEV_QUEUE"
    else
        echo "Installiert: nein"
    fi
}

gd_dev_install() {
    local main_domain wings_domain email_default
    if gd_dev_installed; then
        gd_msg "⚗ Dev-Instanz" "Die Dev-Instanz ist bereits installiert ($GD_DEV_DIR)." 8 60
        return 0
    fi
    # MariaDB-Version: Ein Upgrade würde das Hauptpanel mit betreffen – deshalb hier nicht automatisch
    if command -v mariadb >/dev/null 2>&1 && ! gd_panel2_mariadb_ok; then
        gd_msg "✖ MariaDB zu alt" "Pterodactyl 2.0 braucht MariaDB 10.11 oder neuer, installiert ist $(mariadb --version | grep -oE '[0-9]+\.[0-9]+' | head -n1).\n\nEin Upgrade würde auch das Hauptpanel betreffen und wird deshalb nicht automatisch durchgeführt. Aktualisiere MariaDB zuerst selbst (Backup vorher!) oder nutze einen anderen Server für die Dev-Instanz." 14 76
        return 1
    fi
    gd_panel2_warning_dialog || return 0

    main_domain="$(gd_conf_get PANEL_DOMAIN)"
    wings_domain="$(gd_conf_get WINGS_FQDN)"
    while true; do
        GD_DOMAIN="$(gd_ask_domain "⚗ Domain für die Dev-Instanz" "Gib eine eigene Domain für die Dev-Instanz ein, z. B. dev.deinedomain.de.\n\nSie muss sich vom Hauptpanel (${main_domain:-?}) unterscheiden und per A-Eintrag auf diesen Server zeigen.")" || return 0
        if [ "$GD_DOMAIN" = "$main_domain" ] || [ "$GD_DOMAIN" = "$wings_domain" ]; then
            gd_msg "Domain belegt" "Diese Domain wird bereits vom Hauptpanel bzw. Wings verwendet. Bitte eine andere Subdomain wählen." 9 70
            continue
        fi
        break
    done
    email_default="$(gd_conf_get PANEL_EMAIL)"
    GD_EMAIL="$(gd_ask_email "✉ E-Mail-Adresse" "E-Mail-Adresse für das SSL-Zertifikat und das Administrator-Konto der Dev-Instanz:" "$email_default")" || return 0
    while true; do
        GD_ADMIN_USER="$(gd_input "☺ Benutzername" "Benutzername für das Administrator-Konto der Dev-Instanz:" "admin" 11 70)" || return 0
        [[ "$GD_ADMIN_USER" =~ ^[A-Za-z0-9._-]{3,191}$ ]] && break
        gd_msg "Ungültiger Benutzername" "Mindestens 3 Zeichen, nur Buchstaben, Zahlen, Punkt, Binde- und Unterstrich." 9 70
    done
    GD_TELEMETRY=false

    gd_yesno "☰ Zusammenfassung" "Dev-Instanz (Pterodactyl 2.0-develop) neben dem Hauptpanel:\n\nDomain:        https://${GD_DOMAIN}\nOrdner:        $GD_DEV_DIR\nDatenbank:     $GD_DEV_DB (Benutzer $GD_DEV_DB_USER)\nQueue-Dienst:  $GD_DEV_QUEUE\nE-Mail:        ${GD_EMAIL}\nBenutzername:  ${GD_ADMIN_USER}\n\nDas Hauptpanel bleibt unverändert. Wings bleibt mit dem Hauptpanel verbunden.\n\nJetzt installieren?" 20 78 || return 0

    GD_ADMIN_PASSWORD="$(gd_gen_password 24)"
    GD_DB_PASSWORD="$(gd_gen_password 48)"
    gd_log "Dev-Instanz: Installation gestartet, domain=$GD_DOMAIN"

    if (
        gd_dev_context
        gd_gauge_open "⚗ Dev-Instanz wird installiert" "Installation wird vorbereitet..."
        gd_panel2_install_steps
        gd_progress 100 "Installation abgeschlossen."
        gd_gauge_close
        gd_conf_set DEV_INSTALL_STATE fertig
    ); then
        gd_conf_set DEV_ADMIN_USER "$GD_ADMIN_USER"
        gd_msg "✔ Dev-Instanz installiert" "Pterodactyl 2.0-develop läuft unter:\n\nhttps://${GD_DOMAIN}\n\nBenutzername:   ${GD_ADMIN_USER}\nE-Mail-Adresse: ${GD_EMAIL}\nPasswort:       ${GD_ADMIN_PASSWORD}\n\nSpeichere die Zugangsdaten jetzt, sie werden nicht noch einmal angezeigt.\n\nHinweis: Wings gehört zum Hauptpanel. Für Gameserver in der Dev-Instanz brauchst du eine eigene Node auf einem anderen Server." 20 78
    else
        gd_warn_colors_on
        if gd_yesno "✖ Dev-Instanz fehlgeschlagen" "Die Installation der Dev-Instanz ist fehlgeschlagen (Details im Log: $GD_LOG).\n\nSollen die angelegten Reste (Ordner, Datenbank, nginx, Dienst) entfernt werden? Das Hauptpanel ist davon nicht betroffen." 13 76; then
            gd_warn_colors_off
            gd_dev_remove_files
        fi
        gd_warn_colors_off
        return 1
    fi
}

gd_dev_update() {
    gd_dev_installed || { gd_msg "⚗ Dev-Instanz" "Es ist keine Dev-Instanz installiert." 8 50; return 1; }
    ( gd_dev_context; gd_panel2_update )
}

gd_dev_remove_files() {
    # Entfernt alle Bestandteile der Dev-Instanz (ohne Rückfrage – die stellt der Aufrufer)
    {
        [ -f "$GD_DEV_DIR/artisan" ] && (cd "$GD_DEV_DIR" && php artisan down 2>/dev/null || true)
        systemctl disable --now "$GD_DEV_QUEUE" 2>/dev/null || true
        rm -f "/etc/systemd/system/${GD_DEV_QUEUE}.service"
        systemctl daemon-reload
        rm -f "/etc/nginx/sites-enabled/$GD_DEV_NGINX_CONF" "/etc/nginx/sites-available/$GD_DEV_NGINX_CONF"
        nginx -t && systemctl reload nginx || true
        if command -v mariadb >/dev/null 2>&1; then
            gd_mysql -e "DROP DATABASE IF EXISTS \`${GD_DEV_DB}\`; DROP USER IF EXISTS '${GD_DEV_DB_USER}'@'127.0.0.1'; FLUSH PRIVILEGES;" || true
        fi
        crontab -l 2>/dev/null | grep -vF "${GD_DEV_DIR}/artisan schedule:run" | crontab - || true
        rm -rf "$GD_DEV_DIR"
        sed -i "/^${GD_DEV_PREFIX}/d" "$GD_CONF_FILE" 2>/dev/null
    } >> "$GD_LOG" 2>&1
    gd_log "Dev-Instanz entfernt."
    return 0
}

gd_dev_remove() {
    gd_dev_installed || { gd_msg "⚗ Dev-Instanz" "Es ist keine Dev-Instanz installiert." 8 50; return 1; }
    gd_warn_colors_on
    if ! gd_yesno "✖ Dev-Instanz entfernen" "Die Dev-Instanz (https://$(gd_conf_get DEV_PANEL_DOMAIN)) wird komplett entfernt: Ordner $GD_DEV_DIR, Datenbank $GD_DEV_DB, nginx-Konfiguration und Dienst $GD_DEV_QUEUE.\n\nDas Hauptpanel bleibt unverändert. Fortfahren?" 13 76; then
        gd_warn_colors_off
        return 0
    fi
    gd_warn_colors_off
    gd_dev_remove_files
    gd_msg "✔ Entfernt" "Die Dev-Instanz wurde entfernt. Das SSL-Zertifikat bleibt unter /etc/letsencrypt erhalten." 9 70
}

gd_dev_menu() {
    local c
    while true; do
        c=$(gd_submenu "⚗ Dev-Instanz: Pterodactyl 2.0 nebenbei" "$(gd_dev_status_text)\n\nEine zweite, getrennte Installation von Pterodactyl 2.0-develop unter eigener Domain – zum Testen, ohne das Hauptpanel anzufassen." \
            "1" "✚ Dev-Instanz installieren" \
            "2" "↑ Dev-Instanz aktualisieren (neuester Branch-Stand)" \
            "3" "☰ Logs der Dev-Instanz anzeigen" \
            "4" "✖ Dev-Instanz entfernen") || return
        case "$c" in
            1) gd_dev_install ;;
            2) gd_dev_update ;;
            3)
                if [ -d "$GD_DEV_DIR/storage/logs" ]; then
                    whiptail --title "Logs der Dev-Instanz" --scrolltext --msgbox "$(tail -n 200 "$GD_DEV_DIR"/storage/logs/laravel*.log 2>/dev/null | tail -c 6000)" 30 110
                else
                    gd_msg "Logs" "Noch keine Logs vorhanden." 8 40
                fi ;;
            4) gd_dev_remove ;;
            *) return ;;
        esac
    done
}
