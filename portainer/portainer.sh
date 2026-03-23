#!/usr/bin/env bash
set -euo pipefail

STACK_NAME="portainer"
COMPOSE_FILE="$(cd "$(dirname "$0")" && pwd)/docker-compose.yml"

deploy() {
  echo "[+] Deploy da stack: $STACK_NAME"
  docker stack deploy -c "$COMPOSE_FILE" "$STACK_NAME"
  echo "[✓] Stack $STACK_NAME deployed"
  echo ""
  echo "Acesse: https://manager1.vitorianoernandes.dev"
  echo ""
  echo "Verificar status:"
  echo "  docker stack services $STACK_NAME"
  echo "  docker service logs ${STACK_NAME}_portainer --follow"
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
  docker service logs "${STACK_NAME}_portainer" --follow --tail 100
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
