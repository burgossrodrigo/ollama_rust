# ==============================================================================
# CONFIGURAÇÕES DO PROJETO (Configure aqui)
# ==============================================================================
project_id      := "SEU_ID_DO_PROJETO_GCP"
region          := "us-east1"
zone            := "us-east1-b"
github_repo     := "SEU_USUARIO_GITHUB/SEU_REPOSITORIO"
cluster_name    := "ollama-qwen-cluster" # Nome que você vai dar ao GKE no Terraform
artifact_repo   := "api-repo"            # Nome do repositório de imagens no GCP

# Variáveis derivadas (automáticas)
gcp_pool        := "github-pool"
gcp_provider    := "github-provider"
sa_email        := "gh-actions-deployer@" + project_id + ".iam.gserviceaccount.com"

# ==============================================================================
# COMANDOS PRINCIPAIS
# ==============================================================================

# Lista todos os comandos disponíveis
default:
    @just --list

# 1. Configura todo o OIDC no GCP (Rode isso uma única vez via Cloud Shell/Terminal local)
setup-oidc:
    @echo "=== [1/6] Ativando APIs necessárias ==="
    gcloud services enable iamcredentials.googleapis.com --project="{{project_id}}"

    @echo "=== [2/6] Criando Workload Identity Pool ==="
    gcloud iam workload-identity-pools create "{{gcp_pool}}" \
        --project="{{project_id}}" \
        --location="global" \
        --display-name="GitHub Actions Pool" || true

    @echo "=== [3/6] Criando Provedor OIDC ==="
    gcloud iam workload-identity-pools providers create-oidc "{{gcp_provider}}" \
        --project="{{project_id}}" \
        --location="global" \
        --workload-identity-pool="{{gcp_pool}}" \
        --display-name="GitHub Provider" \
        --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
        --issuer-uri="https://token.actions.githubusercontent.com" || true

    @echo "=== [4/6] Criando Service Account para Deploy ==="
    gcloud iam service-accounts create "gh-actions-deployer" \
        --project="{{project_id}}" \
        --display-name="GitHub Actions Deployer" || true

    @echo "=== [5/6] Atribuindo permissão de Owner para a Service Account ==="
    gcloud projects add-iam-policy-binding "{{project_id}}" \
        --member="serviceAccount:{{sa_email}}" \
        --role="roles/owner" > /dev/null

    @echo "=== [6/6] Vinculando o Repositório GitHub à Service Account ==="
    @NUM_PROJETO=$$(gcloud projects describe {{project_id}} --format='value(projectNumber)'); \
    gcloud iam service-accounts add-iam-policy-binding "{{sa_email}}" \
        --project="{{project_id}}" \
        --role="roles/iam.workloadIdentityUser" \
        --member="principalSet://iam.googleapis.com/projects/$$NUM_PROJETO/locations/global/workloadIdentityPools/{{gcp_pool}}/attribute.repository/{{github_repo}}" > /dev/null

    @echo ""
    @echo "=============================================================================="
    @echo "🎉 CONFIGURAÇÃO CONCLUÍDA COM SUCESSO!"
    @echo "=============================================================================="
    @echo "Copie os valores abaixo e salve nas Variables (não Secrets) do seu GitHub:"
    @echo ""
    @echo "GCP_PROJECT_ID: {{project_id}}"
    @echo "GCP_SERVICE_ACCOUNT: {{sa_email}}"
    @echo "GCP_WORKLOAD_PROVIDER:"
    @gcloud iam workload-identity-pools providers describe "{{gcp_provider}}" \
        --project="{{project_id}}" \
        --location="global" \
        --workload-identity-pool="{{gcp_pool}}" \
        --format="value(name)"

# 2. Testa e roda o ambiente de desenvolvimento local via Docker Compose
dev-local:
    @echo "Iniciando ambiente local (Rust API + Ollama)..."
    docker compose up --build

# 3. Executa a pipeline do Terraform localmente (Útil para debugar a pasta /iac)
tf-deploy:
    @echo "Iniciando Terraform..."
    cd iac && terraform init && terraform apply -auto-approve

# Destrói toda a infraestrutura criada pelo Terraform para não gerar custos indesejados
tf-destroy:
    @echo "🚨 PERIGO: Destruindo toda a infraestrutura do GCP..."
    cd iac && terraform destroy -auto-approve

# 4. Comandos de utilidade para o deploy manual do Backend (se necessário)
build-and-push-api:
    @echo "Autenticando Docker no GCP..."
    gcloud auth configure-docker {{region}}-docker.pkg.dev --project={{project_id}}
    @echo "Compilando e buildando a imagem da API..."
    docker build -t {{region}}-docker.pkg.dev/{{project_id}}/{{artifact_repo}}/api-rust:latest ./api
    @echo "Empurrando imagem para o Artifact Registry..."
    docker push {{region}}-docker.pkg.dev/{{project_id}}/{{artifact_repo}}/api-rust:latest

# Conecta o seu terminal local ao cluster GKE que o Terraform acabou de criar
connect-gke:
    gcloud container clusters get-credentials {{cluster_name}} --zone {{zone}} --project {{project_id}}
