#!/usr/bin/env bash
# Startskript für den Server des Krüger Content Assistenten.
# Enthält keine Geheimnisse. Ablauf:
#  1. Docker und Git installieren, falls sie fehlen
#  2. Zugangsschlüssel (nur Lesen) für das private Repository erzeugen
#  3. Öffentlichen Schlüssel anzeigen (ist nicht geheim) und warten,
#     bis er in GitHub freigegeben ist
#  4. Software holen und Einrichtung starten (deploy/bootstrap.sh)
set -eu

HOST="${1:-1hqc294.cserverhost.cloud}"
REPO="git@github.com:KruegerImmofinanz/krueger-content-assistent.git"
KEY=/root/.ssh/kca_deploy
export GIT_SSH_COMMAND="ssh -i $KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
export DEBIAN_FRONTEND=noninteractive

echo "Schritt 1/4: Docker und Git installieren (dauert 1-3 Minuten) ..."
apt-get update -qq
apt-get install -y -qq git ca-certificates curl >/dev/null
if ! docker compose version >/dev/null 2>&1; then
  if ! apt-get install -y -qq docker.io docker-compose-v2 >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
  fi
fi
systemctl enable --now docker >/dev/null 2>&1 || true
docker compose version

echo "Schritt 2/4: Zugangsschlüssel erzeugen ..."
mkdir -p /root/.ssh
chmod 700 /root/.ssh
if [ ! -f "$KEY" ]; then
  ssh-keygen -t ed25519 -N '' -C kca-server -f "$KEY" -q
fi

echo
echo "Schritt 3/4: Bitte die folgende Zeile komplett kopieren und an Claude schicken:"
echo "------------------------------------------------------------"
cat "$KEY.pub"
echo "------------------------------------------------------------"
echo "Warte auf Freigabe in GitHub (prüft alle 15 Sekunden) ..."
until git ls-remote "$REPO" >/dev/null 2>&1; do
  sleep 15
  printf '.'
done
echo
echo "Schritt 4/4: Freigabe erkannt. Hole Software und richte alles ein ..."

if [ -d /opt/kca/.git ]; then
  git -C /opt/kca pull --ff-only
else
  git clone "$REPO" /opt/kca
fi

DOMAIN="$HOST" bash /opt/kca/deploy/bootstrap.sh 2>&1 | tee /root/kca-bootstrap.log
