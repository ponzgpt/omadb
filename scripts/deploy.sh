#!/usr/bin/env bash
# Build HEAD on hoid and roll it out as a Swarm service behind Dokploy's Traefik.
set -euo pipefail

APP=omadb
DOMAIN=${DOMAIN:-omadb.technoir.cloud}
PORT=80
HOST=${HOST:-hoid}

cd "$(git rev-parse --show-toplevel)"
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "Commit first: deploys are tied to a SHA." >&2; exit 1; }
scripts/check.sh
SHA=$(git rev-parse --short HEAD)

echo "→ $APP:$SHA → $HOST"
git archive --format=tar HEAD | ssh "$HOST" "rm -rf /opt/$APP/$SHA && mkdir -p /opt/$APP/$SHA && tar -x -C /opt/$APP/$SHA"
ssh "$HOST" "docker build -q -t $APP:$SHA /opt/$APP/$SHA" >/dev/null

ssh "$HOST" bash -s <<REMOTE
set -euo pipefail
HC="curl -fsS http://127.0.0.1:$PORT/healthz >/dev/null || exit 1"
if docker service inspect $APP >/dev/null 2>&1; then
  docker service update --quiet --no-resolve-image --image $APP:$SHA --health-cmd "\$HC" $APP
else
  # SQLite: one writer, so stop-first. SECRET_KEY_BASE is born here and never leaves the server.
  docker service create --quiet --no-resolve-image --name $APP --network dokploy-network --replicas 1 \
    --update-order stop-first --mount type=volume,source=$APP-data,target=/rails/storage \
    --env SECRET_KEY_BASE=\$(openssl rand -hex 64) --health-cmd "\$HC" --health-start-period 60s $APP:$SHA
fi
cat > /etc/dokploy/traefik/dynamic/$APP.yml <<YML
http:
  routers:
    $APP-http:
      rule: Host(\\\`$DOMAIN\\\`)
      service: $APP-svc
      middlewares: [redirect-to-https]
      entryPoints: [web]
    $APP-https:
      rule: Host(\\\`$DOMAIN\\\`)
      service: $APP-svc
      entryPoints: [websecure]
      tls: { certResolver: letsencrypt }
  services:
    $APP-svc:
      loadBalancer:
        servers: [{ url: "http://$APP:$PORT" }]
        passHostHeader: true
YML
# keep the current and previous build: source trees and images
ls -1dt /opt/$APP/*/ | tail -n +3 | xargs -r rm -rf
docker images $APP --format '{{.Tag}}' | tail -n +3 | xargs -r -I{} docker rmi $APP:{} >/dev/null 2>&1 || true
REMOTE

for _ in $(seq 45); do curl -fsS "https://$DOMAIN/healthz" >/dev/null 2>&1 && { echo "✓ https://$DOMAIN"; exit 0; }; sleep 2; done
echo "✗ https://$DOMAIN/healthz not answering; roll back: ssh $HOST docker service rollback $APP" >&2; exit 1
