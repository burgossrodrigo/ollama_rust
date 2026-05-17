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
web_domain      := "chat.SEU_DOMINIO.com" # Domínio do frontend (usado no ManagedCertificate)

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

# Mostra os requisitos e a ordem correta de execução para o primeiro deploy
help:
    @echo ""
    @echo "============================================================"
    @echo " ollama-rust — Guia de primeiro deploy"
    @echo "============================================================"
    @echo ""
    @echo " PRE-REQUISITOS (instale antes de rodar qualquer comando):"
    @echo "   - gcloud CLI  : https://cloud.google.com/sdk/docs/install"
    @echo "   - terraform   : https://developer.hashicorp.com/terraform/install"
    @echo "   - docker      : https://docs.docker.com/engine/install"
    @echo "   - node >= 20  : https://nodejs.org"
    @echo "   - just        : cargo install just"
    @echo ""
    @echo "   Autenticar no GCP antes de tudo:"
    @echo "     gcloud auth login"
    @echo "     gcloud auth application-default login"
    @echo "     gcloud config set project SEU_PROJECT_ID"
    @echo ""
    @echo " ORDEM DE EXECUCAO (primeira vez):"
    @echo ""
    @echo "   1. just enable-apis          # Ativa as APIs GCP necessarias"
    @echo "   2. just create-tf-bucket     # Cria bucket GCS para estado do Terraform"
    @echo "   3. just setup-oidc           # Configura OIDC para o GitHub Actions"
    @echo "   4. just create-registry      # Cria o Artifact Registry para as imagens"
    @echo "   5. just build-and-push-api   # Build e push da API Rust"
    @echo "   6. just build-and-push-web   # Build e push do frontend React"
    @echo "   7. just tf-deploy            # Sobe toda a infra no GKE via Terraform"
    @echo "   8. just connect-gke          # Configura o kubectl para o cluster"
    @echo ""
    @echo " DEPLOY CONTINUO (apos infra criada):"
    @echo "   just build-and-push-api      # Atualiza so a API"
    @echo "   just build-and-push-web      # Atualiza so o frontend"
    @echo "   just build-and-push-all      # Atualiza tudo"
    @echo ""
    @echo " OUTROS:"
    @echo "   just dev-local               # Roda localmente via Docker Compose"
    @echo "   just tf-destroy              # PERIGO: destroi toda a infra"
    @echo "   just disable-apis            # Desativa APIs do GCP (evita cobranca)"
    @echo "   just enable-apis             # Reativa as APIs antes de usar"
    @echo "============================================================"
    @echo ""

# 0a. Cria o bucket GCS para armazenar o estado do Terraform
create-tf-bucket:
    gcloud storage buckets create gs://{{project_id}}-tfstate \
        --project="{{project_id}}" \
        --location="{{region}}" \
        --uniform-bucket-level-access
    gcloud storage buckets update gs://{{project_id}}-tfstate \
        --versioning
    @echo "[OK] Bucket gs://{{project_id}}-tfstate criado com versionamento."
    @echo "Descomente o backend 'gcs' em iac/main.tf e rode 'just tf-init'."

# Desativa todas as APIs GCP do projeto (evita cobranças quando nao estiver usando)
disable-apis:
    @echo "=== Desativando APIs do GCP ==="
    gcloud services disable \
        artifactregistry.googleapis.com \
        container.googleapis.com \
        containerregistry.googleapis.com \
        compute.googleapis.com \
        iam.googleapis.com \
        iamcredentials.googleapis.com \
        cloudresourcemanager.googleapis.com \
        dns.googleapis.com \
        certificatemanager.googleapis.com \
        --project="{{project_id}}" --force
    @echo "[OK] APIs desativadas."

# 0b. Ativa todas as APIs GCP necessárias para o projeto (rode uma única vez)
enable-apis:
    @echo "=== Ativando APIs do GCP ==="
    gcloud services enable \
        artifactregistry.googleapis.com \
        container.googleapis.com \
        containerregistry.googleapis.com \
        compute.googleapis.com \
        iam.googleapis.com \
        iamcredentials.googleapis.com \
        cloudresourcemanager.googleapis.com \
        dns.googleapis.com \
        certificatemanager.googleapis.com \
        --project="{{project_id}}"
    @echo "[OK] APIs ativadas. Aguarde ~1 min antes de continuar."

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
# Roda em dois passes: primeiro cria o cluster GKE, depois aplica os recursos Kubernetes.
tf-deploy:
    @echo "[1/2] Subindo infraestrutura GCP (VPC, GKE cluster, node pool)..."
    cd iac && terraform init && terraform apply -auto-approve \
        -var="project_id={{project_id}}" \
        -var="api_image={{region}}-docker.pkg.dev/{{project_id}}/{{artifact_repo}}/api-rust:latest" \
        -var="web_image={{region}}-docker.pkg.dev/{{project_id}}/{{artifact_repo}}/web:latest" \
        -var="web_domain={{web_domain}}" \
        -target=google_compute_network.vpc \
        -target=google_compute_subnetwork.subnet \
        -target=google_compute_router.router \
        -target=google_compute_router_nat.nat \
        -target=google_container_cluster.main \
        -target=google_container_node_pool.gpu_spot \
        -target=google_dns_managed_zone.web

    @echo "[1/2] Conectando kubectl ao cluster..."
    gcloud container clusters get-credentials {{cluster_name}} --zone {{zone}} --project {{project_id}}

    @echo "[2/2] Aplicando recursos Kubernetes (deployments, services, ingress, DNS)..."
    cd iac && terraform apply -auto-approve \
        -var="project_id={{project_id}}" \
        -var="api_image={{region}}-docker.pkg.dev/{{project_id}}/{{artifact_repo}}/api-rust:latest" \
        -var="web_image={{region}}-docker.pkg.dev/{{project_id}}/{{artifact_repo}}/web:latest" \
        -var="web_domain={{web_domain}}"

# Destrói toda a infraestrutura para evitar custos
tf-destroy:
    @echo "[1/2] Destruindo recursos Kubernetes (ingress, deployments, services)..."
    cd iac && terraform destroy -auto-approve \
        -var="project_id={{project_id}}" \
        -var="api_image={{region}}-docker.pkg.dev/{{project_id}}/{{artifact_repo}}/api-rust:latest" \
        -var="web_image={{region}}-docker.pkg.dev/{{project_id}}/{{artifact_repo}}/web:latest" \
        -var="web_domain={{web_domain}}" \
        -target=kubernetes_ingress_v1.web \
        -target=kubernetes_manifest.web_cert \
        -target=kubernetes_deployment.web \
        -target=kubernetes_deployment.api \
        -target=kubernetes_deployment.ollama \
        -target=kubernetes_service.web \
        -target=kubernetes_service.api \
        -target=kubernetes_service.ollama \
        -target=kubernetes_persistent_volume_claim.ollama_models \
        -target=kubernetes_namespace.ollama \
        -target=google_dns_record_set.chat

    @echo "[2/2] Destruindo infraestrutura GCP (cluster, rede, DNS)..."
    cd iac && terraform destroy -auto-approve \
        -var="project_id={{project_id}}" \
        -var="api_image={{region}}-docker.pkg.dev/{{project_id}}/{{artifact_repo}}/api-rust:latest" \
        -var="web_image={{region}}-docker.pkg.dev/{{project_id}}/{{artifact_repo}}/web:latest" \
        -var="web_domain={{web_domain}}"

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
    @echo "[build] Web (bundle local)..."
    cd web && npm ci && npm run build
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
