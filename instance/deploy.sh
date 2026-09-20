#!/usr/bin/env bash
# Deploy da API. Chamado pelo CodeBuild via ssm:SendCommand, e pelo user_data
# no primeiro boot. Recebe a tag da imagem (o SHA do commit).
set -euo pipefail

TAG="${1:?uso: deploy.sh <tag-da-imagem>}"
DIR=/opt/seniors
ANTERIOR="$DIR/.previous"

cd "$DIR"
# shellcheck disable=SC1091
source "$DIR/static.env"

echo "deploy: iniciando $TAG"

# Guarda o que está no ar antes de trocar: é o alvo do rollback.
ATUAL="$(grep -E '^IMAGE_TAG=' "$DIR/.env" 2>/dev/null | cut -d= -f2 || true)"
[ -n "$ATUAL" ] && echo "$ATUAL" > "$ANTERIOR"

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REPO" >/dev/null
docker pull "$ECR_REPO:$TAG"

# A partir daqui há segredo em variável: nada de rastro no log do SSM.
set +x
{
  echo "APP_ENV=production"
  echo "LOG_LEVEL=INFO"
  echo "TRUST_PROXY_HEADERS=true"
  aws ssm get-parameter --name /seniors/api/config --region "$AWS_REGION" \
    --query Parameter.Value --output text

  DB_JSON="$(aws secretsmanager get-secret-value --secret-id "$DB_SECRET_ARN" \
    --region "$AWS_REGION" --query SecretString --output text)"
  DB_USER="$(echo "$DB_JSON" | python3 -c 'import json,sys;print(json.load(sys.stdin)["username"])')"
  DB_PASS="$(echo "$DB_JSON" | python3 -c 'import json,sys,urllib.parse;print(urllib.parse.quote(json.load(sys.stdin)["password"],safe=""))')"
  echo "DATABASE_URL=postgresql+psycopg://${DB_USER}:${DB_PASS}@${DB_HOST}:5432/${DB_NAME}?sslmode=require"

  API_JSON="$(aws secretsmanager get-secret-value --secret-id "$API_SECRET_ARN" \
    --region "$AWS_REGION" --query SecretString --output text)"
  echo "COGNITO_CLIENT_SECRET=$(echo "$API_JSON" | python3 -c 'import json,sys;print(json.load(sys.stdin)["cognito_client_secret"])')"
} > "$DIR/api.env"
chmod 600 "$DIR/api.env"
chown root:root "$DIR/api.env"

# Migration ANTES de trocar o container: por alguns segundos o schema novo
# convive com o código antigo, então migration destrutiva exige duas entregas.
echo "deploy: aplicando migrations"
docker run --rm --env-file "$DIR/api.env" "$ECR_REPO:$TAG" alembic upgrade head

echo "IMAGE_TAG=$TAG" > "$DIR/.env"
docker compose -f "$DIR/compose.yaml" up -d --remove-orphans

# /ready, não /health: o /health responde ok sem tocar no banco, então um
# container com DATABASE_URL errada passaria e o rollback nunca dispararia.
echo "deploy: aguardando /ready"
for _ in $(seq 1 30); do
  if curl -sf -m 3 http://127.0.0.1/ready >/dev/null 2>&1; then
    echo "deploy: $TAG no ar"
    docker image prune -f >/dev/null 2>&1 || true
    exit 0
  fi
  sleep 2
done

echo "deploy: /ready nao respondeu em 60s" >&2
if [ -s "$ANTERIOR" ]; then
  VOLTA="$(cat "$ANTERIOR")"
  echo "deploy: revertendo para $VOLTA" >&2
  echo "IMAGE_TAG=$VOLTA" > "$DIR/.env"
  docker compose -f "$DIR/compose.yaml" up -d --remove-orphans
fi
exit 1
