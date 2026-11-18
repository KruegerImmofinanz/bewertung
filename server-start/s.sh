#!/usr/bin/env bash
# Startskript für den Server des Krüger Content Assistenten.
# Enthält keine Geheimnisse. Ablauf:
#  1. Zugangsschlüssel (nur Lesen) für das private Repository erzeugen
#  2. Öffentlichen Schlüssel kurz unter https://HOST/key.txt bereitstellen
#  3. Warten, bis der Schlüssel in GitHub freigegeben ist
#  4. Software holen und Einrichtung starten (deploy/bootstrap.sh)
set -eu

HOST="${1:-1hqc294.cserverhost.cloud}"
REPO="git@github.com:KruegerImmofinanz/krueger-content-assistent.git"
KEY=/root/.ssh/kca_deploy
export GIT_SSH_COMMAND="ssh -i $KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

mkdir -p /root/.ssh
chmod 700 /root/.ssh
if [ ! -f "$KEY" ]; then
  ssh-keygen -t ed25519 -N '' -C kca-server -f "$KEY" -q
fi

mkdir -p /srv/k
cp "$KEY.pub" /srv/k/key.txt
docker rm -f keyshare >/dev/null 2>&1 || true
docker run -d --name keyshare -p 80:80 -p 443:443 -v /srv/k:/srv caddy \
  caddy file-server --root /srv --domain "$HOST" >/dev/null

echo
echo "Schlüssel bereitgestellt: https://$HOST/key.txt"
echo "Warte auf Freigabe in GitHub (prüft alle 15 Sekunden) ..."
until git ls-remote "$REPO" >/dev/null 2>&1; do
  sleep 15
  printf '.'
done
echo
echo "Freigabe erkannt. Hole Software ..."

docker rm -f keyshare >/dev/null 2>&1 || true
rm -rf /srv/k
if [ -d /opt/kca/.git ]; then
  git -C /opt/kca pull --ff-only
else
  git clone "$REPO" /opt/kca
fi

DOMAIN="$HOST" bash /opt/kca/deploy/bootstrap.sh 2>&1 | tee /root/kca-bootstrap.log
