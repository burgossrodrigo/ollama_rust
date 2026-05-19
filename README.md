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

## Troubleshooting

### Node pool stuck creating / `GCE_STOCKOUT`

**Symptom**: `google_container_node_pool.gpu_spot` stays in `Still creating...` for more than 15 minutes, or fails with `GCE_STOCKOUT`.

**Cause**: No Spot T4 inventory available in the selected zone.

**Debug**:
```bash
just debug-node-pool   # shows the last node pool operation and its error message
```

**Fix**: Change the `zone` in your `justfile` and redeploy.

```
zone := "us-east1-c"   # try us-east1-c or us-east1-d
```

```bash
just tf-destroy && just tf-deploy
```

> If all zones in the region are out of stock, change `region` and `zone` together (e.g. `us-central1` / `us-central1-a`). Note: the Artifact Registry is regional — if you change regions, recreate the registry with `just create-registry` and push the images again.

---

### GPU quota is zero

**Symptom**: Node pool fails immediately with a quota error.

**Debug**:
```bash
just debug-gpu-quota
```

**Fix**: Go to **GCP Console → IAM & Admin → Quotas**, search for `NVIDIA T4 GPUs`, select your region, and request a limit of `1`. Approval is usually automatic within a few minutes.

---

### `cannot create REST client: no client config`

**Symptom**: Terraform fails on `kubernetes_manifest.web_cert` or any Kubernetes resource during the first deploy.

**Cause**: The Kubernetes provider tries to connect to the cluster before it exists.

**Fix**: This is handled automatically by the two-pass `just tf-deploy`. If you ran `terraform apply` manually, run:

```bash
just connect-gke
cd iac && terraform apply ...   # second pass
```

---

### `deletion_protection` blocks `tf-destroy`

**Symptom**: `Cannot destroy cluster because deletion_protection is set to true`.

**Fix**: Already set to `false` in `main.tf`. If you hit this on an older cluster, update it first:

```bash
cd iac && terraform apply -auto-approve \
  -var="project_id=..." \
  -var="api_image=..." \
  -var="web_image=..." \
  -var="web_domain=..." \
  -target=google_container_cluster.main
```

Then run `just tf-destroy`.

---

### GitHub Actions OIDC: `workload_identity_provider` not found

**Symptom**: `the GitHub Action workflow must specify exactly one of "workload_identity_provider" or "credentials_json"`.

**Cause**: The GitHub repository Variables are missing or empty.

**Fix**:
```bash
just debug-oidc   # prints all values to copy into GitHub Variables
```

Set these 5 variables under **GitHub → Settings → Secrets and variables → Actions → Variables**:

| Variable | Value |
|---|---|
| `GCP_PROJECT_ID` | your project ID |
| `GCP_SERVICE_ACCOUNT` | `gh-actions-deployer@<project>.iam.gserviceaccount.com` |
| `GCP_WORKLOAD_PROVIDER` | output of `just debug-oidc` |
| `GKE_CLUSTER` | your cluster name |
| `GKE_ZONE` | your zone |

---

### Docker build fails: `no space left on device`

**Symptom**: Docker fails to extract a layer with `no space left on device` even though disk usage appears normal.

**Cause**: On btrfs filesystems, metadata chunks can fill up independently of data space.

**Fix**:
```bash
docker system prune -af --volumes        # free Docker cache
sudo btrfs balance start -musage=50 /   # rebalance btrfs metadata
```

---

### ManagedCertificate not becoming `Active`

**Symptom**: TLS is not provisioned after 30+ minutes.

**Debug**:
```bash
just debug-tls
```

**Checklist**:
- DNS NS delegation is set in your registrar (4 NS records for the subdomain)
- `dig chat.your-domain.com A +short` returns the Ingress IP
- The Ingress has the annotation `networking.gke.io/managed-certificates: web-managed-cert`

---

### `terraform_remote_state` / `kubernetes_manifest` blocking destroy

**Symptom**: `terraform destroy` on the monolithic `iac/` root fails with `Failed to construct REST client` on `kubernetes_manifest` resources (e.g. `ManagedCertificate`), even when trying to destroy only GCP resources.

**Cause**: The Kubernetes provider tries to connect to the cluster during plan/destroy, even for unrelated resources. If the cluster is already gone, the whole destroy hangs.

**Fix**: The project is split into two Terraform roots — `iac/infra/` (GCP only) and `iac/k8s/` (Kubernetes only). Always destroy in order:

```bash
just tf-destroy   # destroys k8s first, then infra
```

Never run `terraform destroy` directly in a root that mixes GCP and Kubernetes providers.

---

### PVC stuck in `Pending` / `context deadline exceeded`

**Symptom**: `kubernetes_persistent_volume_claim.ollama_models` times out during `terraform apply` with `context deadline exceeded`.

**Cause**: The `standard-rwo` storage class uses `WaitForFirstConsumer` — the PVC stays `Pending` until a pod actually mounts it. Terraform waits for `Bound` by default and times out.

**Fix**: Set `wait_until_bound = false` on the PVC resource. The PVC will bind automatically once the Ollama pod is scheduled.

---

### Ollama init container: `could not connect to ollama server`

**Symptom**: The `pull-model` init container crashes with `could not connect to ollama server`.

**Cause**: `ollama pull` requires a running Ollama server. The original init container ran `ollama pull` directly without starting the server first.

**Fix**: The init container command now starts the server in the background, waits for it to be ready, pulls the model, then kills the server:

```bash
ollama serve & SERVER_PID=$! && until ollama list > /dev/null 2>&1; do sleep 2; done && ollama pull <model> && kill $SERVER_PID
```

---

### `Unexpected Identity Change` on Kubernetes deployment

**Symptom**: `terraform apply` fails with `Unexpected Identity Change: During the read operation, the Terraform Provider unexpectedly returned a different identity`.

**Cause**: Corrupted partial state from a failed previous apply — the resource exists in the cluster but Terraform's stored identity is stale/empty.

**Fix**: Remove the resource from state and re-import it:

```bash
cd iac/k8s
terraform state rm kubernetes_deployment.<name>
terraform import \
  -var="api_image=..." -var="web_image=..." -var="web_domain=..." \
  kubernetes_deployment.<name> <namespace>/<deployment-name>
```

---

### PSC endpoint blocking subnet deletion

**Symptom**: `terraform destroy` fails because a Private Service Connect endpoint (`gk3-*-pe`) cannot be deleted, blocking VPC/subnet deletion.

**Cause**: GKE creates PSC endpoints automatically for cluster control plane access. These are not managed by Terraform and must be deleted separately.

**Fix**:
```bash
gcloud compute forwarding-rules list --project=<project>
gcloud compute forwarding-rules delete <psc-endpoint-name> --region=<region> --project=<project>
```

If `gcloud` also fails (permission issue), use the GCP Console → VPC Network → Private Service Connect → Connected endpoints.

---

### API pod `Insufficient CPU` on system node

**Symptom**: `ollama-api` pod stays `Pending` with event `0/2 nodes are available: 1 Insufficient cpu, 1 node(s) had untolerated taint`.

**Cause**: The `e2-medium` system node has only ~940m allocatable CPU, which is fully consumed by `kube-system` pods (CoreDNS, metrics-server, etc.), leaving no room for the API pod.

**Fix**: Upgrade the system node pool machine type to `e2-standard-2` in `iac/infra/main.tf`:

```hcl
resource "google_container_node_pool" "system" {
  node_config {
    machine_type = "e2-standard-2"   # was e2-medium
    ...
  }
}
```

Then apply: `cd iac/infra && terraform apply`.

---

### GCLB 30-second timeout on long LLM responses

**Symptom**: Requests to `/prompt` return an error after ~30 seconds for complex prompts (during the model's thinking phase).

**Cause**: The GKE Ingress (Google Cloud Load Balancer) has a default backend timeout of 30 seconds. The Qwen3 8B model can take longer than that before sending the first response token.

**Fix**: Create a `BackendConfig` with a higher `timeoutSec` and attach it to the web Service and Ingress via annotations:

```hcl
resource "kubernetes_manifest" "web_backend_config" {
  manifest = {
    apiVersion = "cloud.google.com/v1"
    kind       = "BackendConfig"
    spec = { timeoutSec = 300 }
  }
}
```

Also increase `proxy_read_timeout` in `web/nginx.conf` to match.

---

### GitHub Actions deploying to wrong region

**Symptom**: CI build succeeds but the image is pushed to `us-east1-docker.pkg.dev` while the cluster and registry are in `us-east4`. Deploy step fails because the image doesn't exist in the correct registry.

**Cause**: The `REGION` env var in the workflow files was hardcoded to the original region and not updated when the cluster was migrated.

**Fix**: Update `REGION` and `IMAGE_PATH` in both `.github/workflows/deploy-api.yml` and `deploy-web.yml`, and hardcode `location: us-east4` in the `get-gke-credentials` step (instead of using `vars.GKE_ZONE` which contained a zone, not a region).

---

### Docker build fails: `dist/` not found

**Symptom**: CI fails with `"/dist": not found` during the Docker build of the web image.

**Cause**: The original `web/Dockerfile` used `COPY dist /usr/share/nginx/html`, assuming the Vite build had already run locally. CI doesn't have a pre-built `dist/`.

**Fix**: Convert to a multi-stage Dockerfile that runs `npm run build` inside Docker:

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:1.27-alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
```

Also ensure `web/package-lock.json` is committed — `npm ci` requires it and it was previously gitignored.

---

## Git hooks (Husky — pre-commit)

After cloning, run `npm install` in the root to install Husky automatically.

Hooks run on every commit:
- `terraform validate` (skipped if `iac/.terraform/` does not exist)
- `cargo check` in `api/`
- `tsc --noEmit` in `web/` (skipped if `web/node_modules` is not installed)
