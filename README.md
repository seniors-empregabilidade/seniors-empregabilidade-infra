# Infraestrutura — Seniors Empregabilidade

Produção na conta AGES `951614974043`, região **us-east-2 (Ohio)**, em Terraform.
O plano completo e as justificativas estão fora deste repo, em `aws-infra-plan-2026-09-19/`.

## Este repositório é público

**Nada aqui pode ser segredo.** Os segredos de verdade vivem em três lugares, nenhum deles no git:

| Segredo | Onde mora |
|---|---|
| Senha do banco | Secrets Manager, gerada e rotacionada pela AWS (`manage_master_user_password`) |
| Client secret do Cognito | Secrets Manager, em `seniors/api` |
| Valores resolvidos do Terraform | O **state**, no bucket S3 privado — nunca no repositório |

### O que não pode entrar aqui

- `*.tfstate` — **é onde os segredos aparecem em claro.** Já está no `.gitignore`; se algum dia aparecer um, considere os segredos vazados e rotacione.
- `terraform.tfvars` — contém e-mail de alerta e outros valores de ambiente. Use o `.example`.
- Saída de `terraform plan` colada em issue ou PR: além de IDs, pode renderizar valor sensível.
- Qualquer chave, token ou senha, inclusive "só para testar".

Este repositório é **privado**, ao contrário dos dois de produto. Consequência: o secret scanning com push protection do GitHub, que é gratuito só em repositório público, **não está disponível aqui**. O substituto é o passo `gitleaks` na CI, que falha o PR se encontrar credencial. Não é motivo para relaxar — ele pega formatos conhecidos, não tudo.

Se o repo um dia virar público, ligar secret scanning e push protection nas configurações; o passo do gitleaks pode ficar assim mesmo.

### O que pode, e por que não é problema

O ID da conta (`951614974043`, no nome do bucket de state) e o client ID do Cognito não são segredos: o primeiro não habilita nada porque todas as roles confiam apenas em serviços AWS, e o segundo não autentica sozinho porque o app client é confidencial e exige `SECRET_HASH`.

## Rodar

```sh
aws login --profile seniors-ages --region us-east-2
export AWS_PROFILE=seniors-ages
cp terraform.tfvars.example terraform.tfvars   # e preencher
terraform init
terraform plan
```

O `apply` é sempre manual, com o plan revisado. Não há `plan` na CI: isso exigiria credencial da AWS no GitHub Actions, e a decisão de manter o CI sem credencial vale aqui também.

## Bootstrap do state (uma vez só, já feito)

O bucket do state é o único recurso criado fora do Terraform, por ovo-e-galinha:

```sh
aws s3api create-bucket --bucket seniors-tfstate-951614974043 \
  --region us-east-2 --create-bucket-configuration LocationConstraint=us-east-2
aws s3api put-bucket-versioning --bucket seniors-tfstate-951614974043 \
  --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket seniors-tfstate-951614974043 \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

O lock é o `use_lockfile` nativo do S3. Não há tabela DynamoDB, e não precisa.

## O que o Terraform NÃO gerencia

**A rede.** VPC, sub-redes, IGW, route tables e security groups foram criados pelo console em 07/09/2026, estão corretos, e entram aqui por `data source` (`data.tf`). Só as tags `Project=seniors` são aplicadas neles, via `aws_ec2_tag`.

Consequência: `terraform destroy` **não** apaga a rede. O teardown de fim de semestre é um procedimento à parte — e também precisa remover `prevent_destroy` e `deletion_protection` do RDS antes.

**O User Pool do Cognito.** Existe desde 10/09 com usuários reais; entra por `data source`. Não criamos um pool de produção separado: o diagrama aprovado desenha um só, e os usuários de produção são os três de teste com senha publicada.

## Restrições da conta que o código assume

Medidas em 19/09/2026 com `--dry-run`, não supostas:

- Só `us-east-2`. Qualquer outra região é negada por SCP.
- EC2 apenas `t2`/`t3`/`t4g` até `medium`. O projeto usa `t4g.nano` (ARM) → imagens Docker precisam ser `linux/arm64`.
- `budgets:*`, `ce:*` e `wafv2` são **negados**. Não adicionar `aws_budgets_budget` nem web ACL: o apply falha.
