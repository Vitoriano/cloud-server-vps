# Infra Docker Swarm

Ambiente Docker Swarm com Traefik como reverse proxy, Portainer para gerenciamento do cluster e Watchtower opcional para atualizar imagens dos contentores.

## Estrutura do Projeto

```text
server/
├── traefik/
│   ├── docker-compose.yml      # Stack do Traefik (entrypoints, TLS, providers)
│   ├── traefik.sh              # Script de deploy/gerenciamento da stack traefik
│   ├── dynamic/
│   │   └── security.yml        # Middlewares dinâmicos (headers, rate-limit, etc.)
│   └── README.md               # Documentação específica do Traefik
├── portainer/
│   ├── docker-compose.yml      # Stack do Portainer + Agent
│   └── portainer.sh            # Script de deploy/gerenciamento da stack portainer
├── watchtower/
│   └── docker-compose.yml      # Atualização automática de imagens (deploy global: 1 por nó)
└── README.md                   # Este guia (visão geral do ambiente)
```

## Arquitetura Atual

- `traefik` publica as portas `80/443` em modo Swarm e roteia tráfego por labels.
- `portainer` roda com `portainer/agent` para administrar o Docker Swarm.
- O banco do Portainer CE é interno (`/data/portainer.db`) e persiste no volume `portainer-data`.
- A rede `network_public` é overlay externa compartilhada entre stacks expostas.
- A rede `network_internal` do Portainer é overlay interna para comunicação com o agent.
- `watchtower` em modo **global** (uma instância por nó, docker.sock local); monitoriza por label e não usa Traefik.

## Pré-requisitos

- Docker Engine com Swarm inicializado.
- DNS apontando para o nó manager que publica `80/443`.
- Portas `80` e `443` liberadas no firewall.

## Deploy das Stacks Existentes

```bash
# Traefik
cd /root/server/traefik
bash traefik.sh deploy

# Portainer
cd /root/server/portainer
bash portainer.sh deploy

# Watchtower (atualização de imagens; opcional)
cd /root/server/watchtower
docker stack deploy -c docker-compose.yml watchtower
```

## Como Lançar um Novo Serviço no Swarm

1. Criar uma pasta para o serviço com seu `docker-compose.yml`.
2. Garantir que o serviço participe da rede `network_public` (se for exposto pelo Traefik).
3. Adicionar labels do Traefik no `deploy.labels`.
4. Fazer deploy com `docker stack deploy`.
5. Validar status, tasks e logs.

Exemplo mínimo:

```yaml
services:
  app:
    image: nginx:alpine
    networks:
      - network_public
    deploy:
      replicas: 1
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.app.rule=Host(`app.seudominio.com`)"
        - "traefik.http.routers.app.entrypoints=websecure"
        - "traefik.http.routers.app.tls.certresolver=letsencrypt"
        - "traefik.http.services.app.loadbalancer.server.port=80"

networks:
  network_public:
    external: true
```

Deploy:

```bash
docker stack deploy -c docker-compose.yml minha-stack
```

## Comandos Úteis do Docker Swarm

```bash
# Estado do cluster
docker node ls
docker info | rg -i "swarm"

# Listar stacks e serviços
docker stack ls
docker stack services <stack>
docker service ls

# Ver tasks (histórico de criação/falha)
docker stack ps <stack> --no-trunc
docker service ps <servico> --no-trunc

# Logs
docker service logs <servico> --tail 100
docker service logs <servico> --follow

# Deploy / atualização
docker stack deploy -c docker-compose.yml <stack>
docker service update --force <servico>
docker service update --image <imagem:tag> <servico>
docker service rollback <servico>

# Escala
docker service scale <servico>=<replicas>

# Remoção
docker stack rm <stack>
docker service rm <servico>

# Redes overlay
docker network ls
docker network inspect network_public
docker network create --driver overlay --attachable network_public
```

## Troubleshooting Rápido

- Serviço reiniciando: `docker service ps <servico> --no-trunc` e `docker service logs <servico>`.
- Serviço não recebe tráfego no Traefik:
  - conferir labels em `deploy.labels`;
  - conferir rede `network_public`;
  - conferir `loadbalancer.server.port`.
- Erro em update de serviço com banco SQLite em volume único:
  - usar `deploy.update_config.order: stop-first`.

