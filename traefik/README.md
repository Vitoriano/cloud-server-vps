# Traefik - Reverse Proxy (Docker Swarm)

Reverse proxy com TLS automático via Let's Encrypt, otimizado para produção no Docker Swarm.

## Estrutura

```
traefik/
├── docker-compose.yml      # Stack definition para Swarm
├── traefik.sh              # Script de deploy/gerenciamento
├── dynamic/
│   └── security.yml        # Middlewares (headers, rate-limit, TLS)
└── README.md
```

## Pré-requisitos

- Docker Engine 24+ com Swarm inicializado
- Portas 80 e 443 liberadas no firewall
- DNS apontando para o IP da VPS

## Passo a Passo

### 1. Inicializar o Swarm (se ainda não fez)

```bash
docker swarm init --advertise-addr <IP_DA_VPS>
```

### 2. Deploy do Traefik

```bash
cd traefik/
bash traefik.sh deploy
```

O script automaticamente:
- Cria a rede `network_public` (overlay, encrypted, attachable)
- Faz deploy da stack `traefik`

### 3. Verificar se subiu

```bash
bash traefik.sh status
```

Aguarde até a coluna `CURRENT STATE` mostrar `Running`.

### 4. Acompanhar logs

```bash
bash traefik.sh logs
```

## Como Conectar Serviços ao Traefik

Qualquer serviço na mesma rede `network_public` pode ser exposto. Adicione estas labels no bloco `deploy.labels` do seu serviço:

```yaml
services:
  meu-app:
    image: minha-imagem:latest
    networks:
      - network_public
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.meu-app.rule=Host(`app.meudominio.com`)"
        - "traefik.http.routers.meu-app.entrypoints=websecure"
        - "traefik.http.routers.meu-app.tls.certresolver=letsencrypt"
        - "traefik.http.routers.meu-app.middlewares=security-headers@file,rate-limit@file"
        - "traefik.http.services.meu-app.loadbalancer.server.port=3000"

networks:
  network_public:
    external: true
```

> **Importante no Swarm**: as labels do Traefik vão em `deploy.labels`, NÃO em `labels` no nível do serviço.

## Middlewares Disponíveis

Definidos em `dynamic/security.yml`, prontos para uso:

| Middleware | Referência | O que faz |
|---|---|---|
| Security Headers | `security-headers@file` | HSTS, XSS, Content-Type, Referrer-Policy, Permissions-Policy |
| Rate Limit | `rate-limit@file` | 100 req/min, burst 200 |
| Compressão | `compress-response@file` | Gzip automático |

Use combinando na label `middlewares`:

```
traefik.http.routers.meu-app.middlewares=security-headers@file,rate-limit@file,compress-response@file
```

## Segurança Aplicada

- **TLS 1.2+** com ciphers fortes (ECDHE + AES-GCM / ChaCha20)
- **Redirect HTTP -> HTTPS** permanente (301)
- **API/Dashboard desabilitados** (sem superfície de ataque)
- **Docker socket read-only** (`:ro`)
- **Rede overlay encrypted** entre nós
- **Limites de recursos** (256MB RAM, 0.5 CPU)
- **Logs em JSON** com headers sensíveis redactados
- **Healthcheck** via ping a cada 30s
- **Rolling update** com rollback automático em caso de falha
- **Log rotation** (máx 3 arquivos de 10MB)

## Gerenciamento

```bash
# Deploy / atualizar
bash traefik.sh deploy

# Ver status dos serviços
bash traefik.sh status

# Acompanhar logs em tempo real
bash traefik.sh logs

# Remover stack
bash traefik.sh remove
```

## Atualizar Versão do Traefik

1. Altere a tag da imagem no `docker-compose.yml`
2. Execute `bash traefik.sh deploy`
3. O Swarm faz rolling update automaticamente com rollback se falhar

## Troubleshooting

**Certificado não emitido:**
- Verifique se a porta 443 está acessível externamente (TLS Challenge)
- Confira o DNS: `dig +short app.meudominio.com`
- Veja os logs: `bash traefik.sh logs`

**Serviço não aparece no Traefik:**
- Confirme que `traefik.enable=true` está em `deploy.labels`
- Confirme que o serviço está na rede `network_public`
- Confirme que `loadbalancer.server.port` aponta para a porta correta do container

**Erro 502 Bad Gateway:**
- O container do serviço pode não estar healthy
- A porta no label `loadbalancer.server.port` pode estar errada
