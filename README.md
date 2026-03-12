# Teleport Enterprise Demo Cluster

Self-hosted Teleport Enterprise cluster on AWS EKS, managed entirely with Terraform. Used for demos, testing, and exploring Teleport features at `peter.teleportdemo.com`.

## What's Deployed

**Teleport cluster** — HA deployment with DynamoDB backend, S3 session storage, and Let's Encrypt TLS via the `teleport-cluster` Helm chart.

**Databases** (4) — all registered with Teleport for auto-provisioned access:
- PostgreSQL, MySQL, MariaDB (Bitnami Helm charts with seed data)
- MongoDB Atlas (cloud-hosted)

**SSH nodes** (10) — containerized Linux distros running the Teleport agent:
- Rocky 9, Rocky 8, Fedora 43, AL2023, Ubuntu 24.04, Ubuntu 22.04, Debian 12, Alpine 3.21, openSUSE Leap 16, Arch Linux

**Game containers** — Pac-Man and Tetris (web apps accessible via Teleport app access)

**Apps** — Grafana, ArgoCD, AWS Console, Coder, Swagger UI

**SSO providers** — GitHub, Google SAML, Okta SAML, Entra ID

**RBAC** — read-only roles, access request/approval workflows, session observation and moderation

## Prerequisites

- AWS account with an EKS cluster and Route53-hosted domain
- AWS CLI profile configured
- Teleport Enterprise license
- SSO provider credentials (GitHub OAuth app, Google/Okta/Entra SAML metadata)
- MongoDB Atlas project and API credentials
- Terraform >= 1.0

## Project Structure

```
teleport-cluster/       # All Terraform configuration
  _config.*.tf          # Providers, variables, outputs, data sources
  teleport.*.tf         # Cluster, backend, DNS, agent, apps, databases
  resource.*.tf         # Supporting infra (databases, nodes, ECR, IAM)
  roles.*.tf            # Teleport RBAC roles (CRDs)
  sso.*.tf              # SSO connector configs
  locals.seed_data.tf   # Database seed data
docker/                 # Dockerfiles for SSH node images (10 distros + 2 games)
docs/                   # Setup guides
```

File naming follows a `prefix.name.tf` convention where the prefix groups related resources.

## Usage

```bash
cd teleport-cluster
terraform init
terraform plan -var-file=your.tfvars
terraform apply -var-file=your.tfvars
```

Container images for the SSH nodes are built on a remote ARM host via `terraform_data` + `local-exec` in `resource.ecr.tf` and pushed to ECR. The builder (`tf-amd64`, docker-container driver with QEMU) must be pre-created on the build host.

## License

See [LICENSE](LICENSE).
