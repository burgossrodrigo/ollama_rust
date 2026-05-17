# ollama-rust

A monorepo for serving a local LLM (Qwen3 8B via Ollama) with a Rust API and a React frontend on GKE.

## Architecture

```
ollama_rust/
├── api/   # Rust backend — Axum + Tokio + SSE streaming + Semaphore-based GPU concurrency control
├── web/   # React frontend — MUI + styled-components, ChatGPT-style interface
└── iac/   # Terraform — VPC, GKE Standard cluster, Spot T4 GPU node pool, Cloud DNS, K8s manifests
```

### `api/` — Rust Backend

- **Framework**: Axum 0.7
- **Streaming**: Server-Sent Events (SSE) — each JSON line from Ollama becomes a `data:` frame
- **Concurrency**: `Arc<Semaphore>` limits simultaneous GPU requests (default: 3)
- **Timeout**: 120s on the reqwest client

### `web/` — React Frontend

- **Stack**: React 18 + TypeScript + Vite
- **UI**: MUI + styled-components
- Built locally and copied into an `nginx:1.27-alpine` image — no Node.js in the container

### `iac/` — Infrastructure (Terraform)

- **Cluster**: GKE Standard, single-zone (`us-east1-b`), to avoid inter-zone traffic costs
- **Node pool**: Spot T4 GPU (up to 90% cheaper than on-demand), auto-repair + auto-upgrade
- **TLS**: GKE ManagedCertificate — provisioned automatically once DNS resolves
- **DNS**: Cloud DNS zone delegated from Porkbun via NS records
- **State**: GCS bucket `ollama-rust-tfstate`

### Kubernetes layout (namespace: `ollama`)

| Pod | Service | Exposed |
|---|---|---|
| `ollama` | `ollama` ClusterIP | No |
| `ollama-api` | `ollama-api` ClusterIP | No |
| `ollama-web` | `ollama-web` NodePort | Yes (via GKE Ingress) |

The nginx in the web pod proxies `/prompt` and `/health` to `ollama-api.ollama.svc.cluster.local:80`.

---

## Prerequisites

Install the following tools before running any commands:

| Tool | Install |
|---|---|
| `gcloud` CLI | https://cloud.google.com/sdk/docs/install |
| `terraform` >= 1.7 | https://developer.hashicorp.com/terraform/install |
| `docker` | https://docs.docker.com/engine/install |
| `node` >= 20 | https://nodejs.org |
| `just` | `cargo install just` |

Authenticate with GCP:

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project ollama-rust
```

---

## Configuration

Copy `example.justfile` to `justfile` and fill in your values at the top:

```just
project_id   := "your-gcp-project-id"
region       := "us-east1"
zone         := "us-east1-b"
github_repo  := "your-username/ollama_rust"
cluster_name := "ollama-qwen-cluster"
artifact_repo := "api-repo"
web_domain   := "chat.your-domain.com"
```

---

## First Deploy (step by step)

### 0. Enable GCP APIs

```bash
just enable-apis
```

Wait ~1 minute before proceeding.

### 1. Create the Terraform state bucket

```bash
just create-tf-bucket
```

Creates `gs://<project_id>-tfstate` with versioning enabled.

### 2. Configure GitHub Actions OIDC (once)

```bash
just setup-oidc
```

Copy the printed values into your GitHub repository Variables (not Secrets):
- `GCP_PROJECT_ID`
- `GCP_SERVICE_ACCOUNT`
- `GCP_WORKLOAD_PROVIDER`

### 3. Create the Artifact Registry

```bash
just create-registry
```

### 4. Build and push images

```bash
just build-and-push-api   # Rust API
just build-and-push-web   # React frontend (built locally, only dist/ goes into the image)
```

### 5. Deploy infrastructure

```bash
just tf-deploy
```

Runs in two passes:
1. Creates VPC, GKE cluster, node pool, and Cloud DNS zone
2. Connects `kubectl` to the cluster, then applies all Kubernetes resources

> The GPU Spot node pool can take 10–20 minutes to provision.

### 6. Configure DNS delegation

After `tf-deploy` finishes, get the Cloud DNS nameservers:

```bash
cd iac && terraform output dns_nameservers
```

In your domain registrar, add 4 `NS` records for the `chat` subdomain pointing to those nameservers. Once propagated, the GKE ManagedCertificate will provision TLS automatically (~15 min).

Verify:

```bash
dig chat.your-domain.com NS +short   # should return ns-cloud-*.googledomains.com
dig chat.your-domain.com A +short    # should return the Ingress IP
curl -I https://chat.your-domain.com  # 200 when TLS is ready
```

---

## Day-to-day commands

```bash
just build-and-push-api   # Rebuild and push the Rust API
just build-and-push-web   # Rebuild and push the React frontend
just build-and-push-all   # Rebuild and push both

just connect-gke          # Reconfigure kubectl for the cluster
just dev-local            # Run locally with Docker Compose
```

---

## Cost management

```bash
just tf-destroy           # Destroy all infrastructure (two-pass: K8s first, then GCP)
just disable-apis         # Disable GCP APIs when not in use
just enable-apis          # Re-enable APIs before resuming work
```

> The Spot T4 node is the main cost driver. Run `just tf-destroy` when not actively using the cluster.

---

## Git hooks (Husky — pre-commit)

After cloning, run `npm install` in the root to install Husky automatically.

Hooks run on every commit:
- `terraform validate` (skipped if `iac/.terraform/` does not exist)
- `cargo check` in `api/`
- `tsc --noEmit` in `web/` (skipped if `web/node_modules` is not installed)
