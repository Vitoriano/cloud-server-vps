#!/usr/bin/env bash
set -euo pipefail

STACK_NAME="traefik"
COMPOSE_FILE="$(cd "$(dirname "$0")" && pwd)/docker-compose.yml"
NETWORK_NAME="network_public"

create_network() {
  if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    echo "[+] Criando rede overlay: $NETWORK_NAME"
    docker network create \
      --driver overlay \
      --attachable \
      --opt encrypted \
      "$NETWORK_NAME"
  else
    echo "[=] Rede $NETWORK_NAME já existe"
  fi
}

deploy() {
  create_network
  echo "[+] Deploy da stack: $STACK_NAME"
  docker stack deploy -c "$COMPOSE_FILE" "$STACK_NAME"
  echo "[✓] Stack $STACK_NAME deployed"
  echo ""
  echo "Verificar status:"
  echo "  docker stack services $STACK_NAME"
  echo "  docker service logs ${STACK_NAME}_traefik --follow"
}

remove() {
  echo "[-] Removendo stack: $STACK_NAME"
  docker stack rm "$STACK_NAME"
  echo "[✓] Stack removida"
}

status() {
  echo "[i] Serviços da stack $STACK_NAME:"
  docker stack services "$STACK_NAME"
  echo ""
  echo "[i] Tasks:"
  docker stack ps "$STACK_NAME" --no-trunc
}

logs() {
  docker service logs "${STACK_NAME}_traefik" --follow --tail 100
}

case "${1:-help}" in
  deploy)  deploy ;;
  remove)  remove ;;
  status)  status ;;
  logs)    logs ;;
  *)
    echo "Uso: $0 {deploy|remove|status|logs}"
    exit 1
    ;;
esac
