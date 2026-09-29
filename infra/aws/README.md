# Deploying NAGARIK's backend to AWS (Step 10)

This is a handover document, not a record of anything already deployed.
Nothing in this repository has been deployed, and no AWS resources have
been created on your behalf — every command below is meant for you (or
whoever operates your AWS account) to run. That's a deliberate project
rule, not a limitation: deployment decisions (account, region, budget,
domain, who holds the credentials) are yours to make.

**What's being deployed:** only the FastAPI backend (`backend/`), as the
container image `backend/Dockerfile` already builds. Supabase (Postgres,
Auth, Storage) stays exactly as configured throughout the project — it's
not part of this deployment, and going to production doesn't require a
different Supabase project unless you want a separate one for prod vs.
dev. The Flutter mobile app is distributed separately, through the Play
Store / App Store — see "Mobile app distribution" at the bottom; that
process is unrelated to deploying this backend and isn't covered by the
CI/CD pipeline here.

## Choosing a path: App Runner vs. ECS/Fargate

Two templates are provided; pick one. Both are plain JSON with every
placeholder value spelled `REPLACE_ME_ACCOUNT_ID` / `REPLACE_ME_REGION` —
find-and-replace those with your real account ID and region before running
anything. (Earlier drafts of these templates carried an explanatory
`_comment` key; it's been removed, because `--cli-input-json` validates
the JSON strictly against the API's shape and rejects unrecognized
top-level keys like `_comment` — the explanation lives here instead.)

- **AWS App Runner** (`apprunner-service.json`) — recommended default. No
  VPC, load balancer, or cluster to design or pay for; you give it a
  container image and it runs it, load-balances it, and gives you HTTPS on
  an `*.awsapprunner.com` URL (or your own domain) out of the box. Right
  fit for a single backend service like this one.
- **ECS on Fargate** (`ecs-task-definition.json`) — for when you already
  run ECS/Fargate, need a VPC/ALB you control, or need things App Runner
  doesn't do (multiple containers per task, reserved capacity, very custom
  networking). More pieces to set up yourself (cluster, VPC, ALB, target
  group, security groups) — not included here since that's specific to
  whatever AWS setup you already have.

The rest of this doc assumes App Runner; the ECS path uses the same ECR
image, secrets, and CI/CD ideas, just with `aws ecs` commands instead of
`aws apprunner` ones.

## One-time setup

Run these once, from a machine with the AWS CLI configured for your
account (`aws configure`, or `aws sso login`).

**1. Create an ECR repository for the image:**

```bash
aws ecr create-repository --repository-name nagarik-api --region <your-region>
```

**2. Put the four Supabase secrets in AWS Secrets Manager** (see
"Secrets management" below for why these four and not the others):

```bash
aws secretsmanager create-secret --name nagarik/supabase-url \
  --secret-string "https://YOUR_PROJECT_REF.supabase.co"
aws secretsmanager create-secret --name nagarik/supabase-anon-key \
  --secret-string "<your anon key>"
aws secretsmanager create-secret --name nagarik/supabase-service-role-key \
  --secret-string "<your service-role key>"
aws secretsmanager create-secret --name nagarik/supabase-jwt-secret \
  --secret-string "<your JWT secret>"
```

**3. Create the IAM role App Runner uses to pull from ECR and read those
secrets** (`AppRunnerECRAccessRole` in the template — trust policy for
`build.apprunner.amazonaws.com`, with `AWSAppRunnerServicePolicyForECRAccess`
attached, plus a policy granting `secretsmanager:GetSecretValue` on the
four ARNs above). The AWS Console's "Create service" wizard can create this
role for you automatically the first time — that's the easiest path if
you're doing the first deploy through the console rather than the CLI.

**4. Build and push the first image manually, once**, so there's an image
for the service to start from:

```bash
cd backend
aws ecr get-login-password --region <your-region> | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.<your-region>.amazonaws.com
docker build -t <account-id>.dkr.ecr.<your-region>.amazonaws.com/nagarik-api:latest .
docker push <account-id>.dkr.ecr.<your-region>.amazonaws.com/nagarik-api:latest
```

**5. Fill in `apprunner-service.json`** — replace every
`REPLACE_ME_ACCOUNT_ID` / `REPLACE_ME_REGION` with your real values — then
create the service:

```bash
aws apprunner create-service --cli-input-json file://infra/aws/apprunner-service.json
```

That's it for the one-time setup. App Runner gives you a service URL
(`https://<random-id>.<region>.awsapprunner.com`) — that's your production
`API_BASE_URL` for the Flutter app's `.env` (see `mobile/.env.example`).

**Custom domain (optional):** App Runner supports associating your own
domain (`aws apprunner associate-custom-domain`) with automatic ACM
certificate provisioning — see the AWS App Runner docs for the exact
DNS records to add; not required to have a working HTTPS endpoint.

## Ongoing deploys: the CI/CD pipeline

Three GitHub Actions workflows live in `.github/workflows/`:

- **`backend-ci.yml`** — runs automatically on every push/PR touching
  `backend/`: `ruff check`, `pytest`, and a Docker build sanity check.
  Verification only, touches no AWS resources.
- **`mobile-ci.yml`** — same idea for `mobile/`: `flutter analyze` and
  `flutter test`. This is the first time this project's Dart code actually
  runs through the Flutter SDK (it was written in a sandbox without one —
  see `mobile/README.md`), so treat its first run's results as something
  to triage, not assume will be clean.
- **`backend-deploy.yml`** — builds the image, pushes it to ECR, and
  redeploys the App Runner service. **Manual only**
  (`workflow_dispatch`, with a confirmation input) — it never runs on a
  push or a schedule. You (or whoever you delegate it to) trigger it from
  the Actions tab when you've decided it's time to ship. This keeps
  "deploy to production" a deliberate human action, matching how this
  whole project has been built.

To make `backend-deploy.yml` work, add these **repository secrets**
(Settings → Secrets and variables → Actions → New repository secret):

| Secret                 | Value                                                              |
| ----------------------- | ------------------------------------------------------------------ |
| `AWS_REGION`            | e.g. `ap-south-1`                                                   |
| `AWS_ROLE_TO_ASSUME`    | ARN of an IAM role GitHub can assume via OIDC (see below)          |
| `ECR_REPOSITORY_URI`    | e.g. `123456789012.dkr.ecr.ap-south-1.amazonaws.com/nagarik-api`   |
| `APP_RUNNER_SERVICE_ARN`| the ARN `aws apprunner create-service` returned                    |

**Why an OIDC role instead of an AWS access key pair:** long-lived AWS
keys stored as GitHub secrets are a standing risk if the repo or a runner
is ever compromised. GitHub's OIDC provider lets you create an IAM role
that trusts *this specific repository* and grants it temporary credentials
per run instead — [AWS's guide for configuring the trust
policy](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc_verify-thumbprint.html)
plus `aws-actions/configure-aws-credentials`'s own README covers the exact
trust-policy JSON. If you'd rather use a plain access key pair instead,
that also works — swap the "Configure AWS credentials" step in
`backend-deploy.yml` for one that reads `AWS_ACCESS_KEY_ID`/
`AWS_SECRET_ACCESS_KEY` secrets instead of `role-to-assume`.

## Secrets management

Four values are genuine secrets (they grant real access to your Supabase
project) and must never sit in plain sight: `SUPABASE_URL` (identifies
which project — low sensitivity alone, but grouped with the others here),
`SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` (bypasses Row Level
Security — the most sensitive of the four), and `SUPABASE_JWT_SECRET`
(anyone with this can forge valid auth tokens). All four:

- Live in **AWS Secrets Manager**, referenced by ARN from the service
  config (`RuntimeEnvironmentSecrets` in the App Runner template,
  `secrets` in the ECS one) — App Runner/ECS fetches them at container
  start, they're never baked into the image or visible in the console's
  plain "environment variables" list.
- Are **never** committed to the repo. `backend/.env` (real values, local
  dev) and `backend/.env.production.example` (documents the shape,
  carries no real values) both stay out of version control —
  `.dockerignore` already excludes `.env` from the built image too.
- Should be **rotated** if you ever suspect exposure — regenerate the key
  in the Supabase dashboard, update the Secrets Manager entry, then
  redeploy (App Runner/ECS pick up the new value on the next deployment,
  not automatically for already-running tasks).

Everything else in `.env.production.example` (`APP_NAME`, `ENVIRONMENT`,
`DEBUG`, CORS origins, the storage bucket name, the signed-URL TTL, the JWT
algorithm) is ordinary configuration, not a secret — plain runtime
environment variables are fine for those.

## Monitoring, logs, and rollback

- **Logs:** App Runner ships stdout/stderr to CloudWatch Logs
  automatically (log group named after the service); the app's own
  logging (`app/core/logging.py`) writes structured lines there. ECS needs
  the `awslogs` log driver configured explicitly — already included in
  `ecs-task-definition.json`.
- **Health checks:** both templates point at `GET /api/v1/health` (fast,
  makes no external calls — see `app/api/v1/endpoints/health.py`). `GET
  /api/v1/health/ready` additionally reports whether Supabase credentials
  are present, useful for a manual check after deploying but not wired as
  the load-balancer health check itself (a transient Supabase hiccup
  shouldn't make App Runner think the whole service is down).
- **Rollback:** App Runner keeps your previous deployments; roll back with
  `aws apprunner start-deployment` after re-pointing at the previous image
  tag (which is why `backend-deploy.yml` tags images with the git SHA, not
  only `latest` — you can always redeploy a specific known-good SHA). For
  ECS, roll back by registering the previous task definition revision and
  updating the service to use it.

## Cost note

App Runner bills for provisioned compute plus a small per-vCPU/memory rate
while running (no free tier); at the `0.25 vCPU` / `0.5 GB` size in the
template, a single always-on instance is roughly the cost of a small EC2
instance per month — check current pricing before committing, and consider
App Runner's auto-scaling-to-zero-adjacent "paused" billing behavior isn't
a thing (unlike Lambda) if traffic is very low and cost-sensitive; a
scheduled scale-down or switching to a smaller compute tier are the levers
available.

## Mobile app distribution

Out of scope for this backend deployment, and not something this project
builds or submits on your behalf — the standard Flutter release process
applies once `flutter create .` has been run and the app built normally on
a machine with the Flutter SDK and the relevant platform tooling (Android
Studio / Xcode):

- Android: `flutter build appbundle` → upload the `.aab` to the Google
  Play Console.
- iOS: `flutter build ipa` → upload via Xcode or
  `xcrun altool`/Transporter to App Store Connect.

Both require your own developer accounts, signing keys/certificates, and
store-listing content — none of which this repository holds an opinion on.
