# ==============================================================================
# CONFIGURAÇÕES DO PROJETO (Configure aqui)
# Copie este arquivo para `justfile` e preencha os valores abaixo.
# ==============================================================================
project_id      := "SEU_ID_DO_PROJETO_GCP"
region          := "us-east1"
zone            := "us-east1-b"
github_repo     := "SEU_USUARIO_GITHUB/SEU_REPOSITORIO"
cluster_name    := "ollama-qwen-cluster"
artifact_repo   := "api-repo"

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

# 1. Configura todo o OIDC no GCP (rode uma única vez via terminal local)
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
    @echo "CONFIGURACAO CONCLUIDA!"
    @echo "=============================================================================="
    @echo "Salve os valores abaixo como Variables (nao Secrets) no GitHub:"
    @echo ""
    @echo "GCP_PROJECT_ID:      {{project_id}}"
    @echo "GCP_SERVICE_ACCOUNT: {{sa_email}}"
    @echo "GKE_CLUSTER:         {{cluster_name}}"
    @echo "GKE_ZONE:            {{zone}}"
    @echo "GCP_WORKLOAD_PROVIDER:"
    @gcloud iam workload-identity-pools providers describe "{{gcp_provider}}" \
        --project="{{project_id}}" \
        --location="global" \
        --workload-identity-pool="{{gcp_pool}}" \
        --format="value(name)"

# 2. Cria o Artifact Registry (rode uma única vez, antes do primeiro push de imagem)
create-registry:
    @echo "=== [1/2] Ativando API do Artifact Registry ==="
    gcloud services enable artifactregistry.googleapis.com --project="{{project_id}}"

    @echo "=== [2/2] Criando repositório Docker ==="
    gcloud artifacts repositories create "{{artifact_repo}}" \
        --repository-format=docker \
        --location="{{region}}" \
        --project="{{project_id}}" \
        --description="Imagens Docker do ollama-rust" || true

    @echo ""
    @echo "Registry criado: {{region}}-docker.pkg.dev/{{project_id}}/{{artifact_repo}}"
    @echo "Rode 'just auth-docker' para autenticar o Docker antes do primeiro push."

# Autentica o Docker local no Artifact Registry
auth-docker:
    gcloud auth configure-docker {{region}}-docker.pkg.dev --project={{project_id}}

# 3. Executa o Terraform (init + apply)
tf-deploy:
    @echo "[tf] Iniciando Terraform..."
    cd iac && terraform init && terraform apply -auto-approve

# Destrói toda a infraestrutura para evitar custos
tf-destroy:
    @echo "PERIGO: Destruindo toda a infraestrutura do GCP..."
    cd iac && terraform destroy -auto-approve

# 4. Build e push manual das imagens (para o primeiro deploy, antes do CI estar ativo)
build-and-push-api: auth-docker
    @echo "[build] API..."
    docker build --platform linux/amd64 \
        -t {{region}}-docker.pkg.dev/{{project_id}}/{{artifact_repo}}/api-rust:latest \
        ./api
    @echo "[push] Pushing api-rust:latest..."
    docker push {{region}}-docker.pkg.dev/{{project_id}}/{{artifact_repo}}/api-rust:latest
    @echo "[OK] api-rust pronta no registry."

build-and-push-web: auth-docker
    @echo "[build] Web..."
    docker build --platform linux/amd64 \
        -t {{region}}-docker.pkg.dev/{{project_id}}/{{artifact_repo}}/web:latest \
        ./web
    @echo "[push] Pushing web:latest..."
    docker push {{region}}-docker.pkg.dev/{{project_id}}/{{artifact_repo}}/web:latest
    @echo "[OK] web pronta no registry."

build-and-push-all: build-and-push-api build-and-push-web

# Conecta o terminal local ao cluster GKE
connect-gke:
    gcloud container clusters get-credentials {{cluster_name}} --zone {{zone}} --project {{project_id}}
