set -euo pipefail

confirm() {
  local prompt="$1"
  local reply
  read -rp "$prompt [y/N]: " reply
  case "$reply" in
    Y|y|J|j) return 0 ;;
    *) return 1 ;;
  esac
}

valid_hostname() {
  local hn="$1"
  if [[ ${#hn} -gt 63 || ${#hn} -eq 0 ]]; then
    return 1
  fi
  if [[ "$hn" =~ ^[A-Za-z0-9]([A-Za-z0-9\-]{0,61}[A-Za-z0-9])?$ ]]; then
    return 0
  fi
  return 1
}

if ! confirm "Next Systems - Server Setup || Möchtest du das Setup jetzt ausführen?"; then
  echo "Next Systems - Server Setup || Abbruch durch Benutzer."
  exit 0
fi

if [ "$EUID" -ne 0 ]; then
  echo "Next Systems - Server Setup || Starte mit sudo neu..."
  exec sudo bash "$0" "$@"
fi

echo "Next Systems - Server Setup || Beginne Setup..."

cd ~
clear

if confirm "Next Systems - Server Setup || Systemaktualisierung & Bereinigung ausführen (apt update, full-upgrade, autoremove, autoclean, fixes)?"; then
  echo "Next Systems - Server Setup || Führe apt-Operationen aus..."
  apt update
  apt full-upgrade -y
  apt autoremove -y
  apt autoclean -y
  apt upgrade --fix-missing -y || true
  apt --fix-broken install -y || true
  apt upgrade --fix-policy -y || true
  echo "Next Systems - Server Setup || apt-Operationen abgeschlossen."
else
  echo "Next Systems - Server Setup || Überspringe Systemaktualisierung."
fi

if confirm "Next Systems - Server Setup || journalctl bereinigen (Logs älter als 7 Tage entfernen)?"; then
  echo "Next Systems - Server Setup || Bereinige journalctl (>7d)..."
  journalctl --vacuum-time=7d || true
  echo "Next Systems - Server Setup || journalctl bereinigt."
else
  echo "Next Systems - Server Setup || Überspringe journalctl-Bereinigung."
fi

clear

if confirm "Next Systems - Server Setup || Exim stoppen & entfernen (auf ALLEN Systemen)?"; then
  echo "Next Systems - Server Setup || Versuche Exim zu stoppen/deaktivieren/entfernen..."
  systemctl stop exim4.service 2>/dev/null || systemctl stop exim.service 2>/dev/null || true
  systemctl disable exim4.service 2>/dev/null || systemctl disable exim.service 2>/dev/null || true
  pkill -f exim || true
  killall exim4 exim 2>/dev/null || true
  apt purge -y 'exim4*' || true
  apt autoremove -y || true
  echo "Next Systems - Server Setup || Exim-Entfernung versucht."
else
  echo "Next Systems - Server Setup || Überspringe Exim-Entfernung."
fi

if confirm "Next Systems - Server Setup || dpkg-reconfigure locales (INTERAKTIV) ausführen?"; then
  if command -v dpkg-reconfigure >/dev/null 2>&1; then
    echo "Next Systems - Server Setup || Starte INTERAKTIVES dpkg-reconfigure locales..."
    dpkg-reconfigure locales || echo "Next Systems - Server Setup || locales reconfigure beendet/abgebrochen."
  else
    echo "Next Systems - Server Setup || dpkg-reconfigure nicht gefunden; überspringe locales."
  fi
else
  echo "Next Systems - Server Setup || Überspringe locales reconfigure."
fi

if confirm "Next Systems - Server Setup || dpkg-reconfigure tzdata (INTERAKTIV) ausführen?"; then
  if command -v dpkg-reconfigure >/dev/null 2>&1; then
    echo "Next Systems - Server Setup || Starte INTERAKTIVES dpkg-reconfigure tzdata..."
    dpkg-reconfigure tzdata || echo "Next Systems - Server Setup || tzdata reconfigure beendet/abgebrochen."
  else
    echo "Next Systems - Server Setup || dpkg-reconfigure nicht gefunden; überspringe tzdata."
  fi
else
  echo "Next Systems - Server Setup || Überspringe tzdata reconfigure."
fi

if confirm "Next Systems - Server Setup || hostname (/etc/hostname), /etc/hosts und /etc/motd setzen (Backup wird erstellt)?"; then
  TS="$(date +%s)"
  echo "Next Systems - Server Setup || Backup von /etc/hosts, /etc/hostname, /etc/motd -> .bak.${TS}"
  cp -a /etc/hosts "/etc/hosts.bak.${TS}" || true
  cp -a /etc/hostname "/etc/hostname.bak.${TS}" || true
  cp -a /etc/motd "/etc/motd.bak.${TS}" || true

  DEFAULT_HOST="nextsystems"
  while true; do
    read -rp "Next Systems - Server Setup || Gib gewünschten Hostname ein (leer = '${DEFAULT_HOST}'): " INPUT_HOST
    # Trim whitespace
    INPUT_HOST="$(echo -n "$INPUT_HOST" | tr -d '[:space:]')"
    if [ -z "$INPUT_HOST" ]; then
      CHOSEN_HOST="$DEFAULT_HOST"
      break
    fi
    if valid_hostname "$INPUT_HOST"; then
      CHOSEN_HOST="$INPUT_HOST"
      break
    else
      echo "Next Systems - Server Setup || Ungültiger Hostname. Erlaubt: Buchstaben, Zahlen, Bindestriche (nicht Anfang/Ende). Versuch's nochmal."
    fi
  done

  echo "Next Systems - Server Setup || Setze Hostname auf: ${CHOSEN_HOST}"
  echo "$CHOSEN_HOST" > /etc/hostname
  hostnamectl set-hostname "$CHOSEN_HOST" || true

  # Entferne vorhandene 127.0.1.1-Zeilen und füge eigenes Mapping hinzu
  sed -i '/^[[:space:]]*127\.0\.1\.1[[:space:]]/d' /etc/hosts || true
  # Füge Mapping ans Ende an (idempotent da wir Backup gemacht haben)
  echo "127.0.1.1 ${CHOSEN_HOST}" >> /etc/hosts

  cat > /etc/motd <<'MOTD'
     _   _ ________   _________    _____  ____  _     _    _ _______ _____ ____  _   _  _____
     | \ | |  ____\ \ / /__   __|  / ____|/ __ \| |   | |  | |__   __|_   _/ __ \| \ | |/ ____|
     |  \| | |__   \ V /   | |    | (___ | |  | | |   | |  | |  | |    | || |  | |  \| | (___
     | . ` |  __|   > <    | |     \___ \| |  | | |   | |  | |  | |    | || |  | | . ` |\___ \
     | |\  | |____ / . \   | |     ____) | |__| | |___| |__| |  | |   _| || |__| | |\  |____) |
     |_| \_|______/_/ \_\  |_|    |_____/ \____/|______\____/   |_|  |_____\____/|_| \_|_____/

MOTD

  echo "Next Systems - Server Setup || Hostname, /etc/hosts und /etc/motd gesetzt."
else
  echo "Next Systems - Server Setup || Überspringe Hostname/Hosts/MOTD-Einstellungen."
fi

if confirm "Next Systems - Server Setup || fail2ban installieren und aktivieren (Standardkonfiguration)?"; then
  echo "Next Systems - Server Setup || Installiere fail2ban..."
  apt update
  apt install -y fail2ban || echo "Next Systems - Server Setup || fail2ban-Installation fehlgeschlagen/oder bereits vorhanden."
  systemctl enable --now fail2ban || true
  echo "Next Systems - Server Setup || fail2ban installiert und aktiviert."
else
  echo "Next Systems - Server Setup || Überspringe fail2ban."
fi

if confirm "Next Systems - Server Setup || UFW installieren und Standard-Ports (OpenSSH, MySQL, HTTP, HTTPS) erlauben und aktivieren?"; then
  echo "Next Systems - Server Setup || Installiere und konfiguriere UFW..."
  apt update
  apt install -y ufw || echo "Next Systems - Server Setup || ufw-Installation fehlgeschlagen/oder bereits vorhanden."
  ufw allow OpenSSH || true
  ufw allow 3306/tcp || true
  ufw allow 80/tcp || true
  ufw allow 443/tcp || true
  ufw --force enable || echo "Next Systems - Server Setup || Aktivieren von UFW fehlgeschlagen."
  echo "Next Systems - Server Setup || UFW konfiguriert und aktiviert."
else
  echo "Next Systems - Server Setup || Überspringe UFW-Konfiguration."
fi

echo "Next Systems - Server Setup || Alle gewünschten Schritte wurden abgearbeitet (sofern ausgewählt)."

if confirm "Next Systems - Server Setup || Möchtest du jetzt neu starten?"; then
  echo "Next Systems - Server Setup || System wird neu gestartet..."
  reboot
else
  echo "Next Systems - Server Setup || Setup beendet. Neustart wurde übersprungen."
fi
