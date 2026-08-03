# AWS Network Lab — Terraform + GitHub Actions

Implements the capstone architecture from the AWS networking learning path:

```
VPC (10.0.0.0/16)
├── Public Subnet  AZ-a (10.0.1.0/24)  ── IGW route, bastion host, NAT Gateway
├── Public Subnet  AZ-b (10.0.2.0/24)  ── IGW route
├── Private Subnet AZ-a (10.0.11.0/24) ── NAT route, app instance, S3-read IAM role
├── Private Subnet AZ-b (10.0.12.0/24) ── NAT route
├── Security Groups: bastion (SSH from your IP), app (SSH from bastion SG only)
├── Custom NACL on private subnets (explicit allow rules incl. ephemeral ports)
└── IAM role on the app instance: least-privilege S3 read + SSM Session Manager
```

GitHub Actions runs `fmt`/`validate`/`plan` on every pull request and comments the
plan directly on the PR, then runs `apply` automatically on merge to `main`.

## Repo layout

```
.
├── main.tf                    # provider, terraform block, data sources
├── variables.tf                # all configurable inputs
├── vpc.tf                     # VPC + Internet Gateway
├── subnets.tf                  # public/private subnets across AZs
├── routing.tf                  # NAT gateway(s) + route tables
├── security.tf                 # security groups + example NACL
├── iam.tf                      # IAM role/policy/instance profile
├── compute.tf                  # bastion + private app EC2 instances
├── outputs.tf                  # useful outputs, incl. ready-to-run SSH commands
├── terraform.tfvars.example    # copy to terraform.tfvars and edit
└── .github/workflows/terraform.yml
```

## 1. Local setup (run it yourself first)

```bash
git clone <this-repo>
cd aws-network-terraform

cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars:
#   - set bastion_allowed_cidr to YOUR_IP/32   (find it: curl ifconfig.me)
#   - set key_pair_name to an existing EC2 key pair name, or leave blank to use SSM only

terraform init
terraform plan
terraform apply
```

After apply, use the printed outputs:

```bash
terraform output ssh_to_bastion
terraform output ssh_to_app_from_bastion
```

Or connect without SSH at all via Session Manager (works because of the IAM role
attached to the app instance):

```bash
aws ssm start-session --target $(terraform output -raw app_private_ip)
```

Tear down when done to avoid ongoing NAT Gateway charges:

```bash
terraform destroy
```

## 2. Wiring up GitHub Actions (OIDC — no stored AWS keys)

The workflow authenticates to AWS using OpenID Connect instead of long-lived
access keys. One-time setup in your AWS account:

**a. Create the OIDC identity provider** (skip if your account already has one
for GitHub Actions):

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

**b. Create an IAM role GitHub Actions will assume**, trusting only this repo:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<YOUR_GH_ORG>/<YOUR_REPO>:*"
        }
      }
    }
  ]
}
```

Attach a policy scoped to what this stack needs (VPC, EC2, IAM role/instance
profile creation) — avoid `AdministratorAccess` even for a lab.

**c. Add the role ARN as a repo secret:**

Settings → Secrets and variables → Actions → New repository secret
`AWS_GITHUB_ACTIONS_ROLE_ARN` = `arn:aws:iam::<ACCOUNT_ID>:role/<your-role-name>`

**d. (Recommended) Enable remote state** — uncomment the `backend "s3"` block in
`main.tf` and point it at an S3 bucket + DynamoDB lock table, so `plan`/`apply`
runs in CI share state correctly instead of each run starting from scratch.

**e. (Recommended) Require manual approval before apply** — under repo
Settings → Environments, create an environment named `production` and add
required reviewers. The workflow already targets this environment for the
apply job.

## 3. How the workflow behaves

| Trigger | Job | What happens |
|---|---|---|
| Pull request touching `*.tf` | `fmt-and-validate` → `plan` | Runs `terraform fmt -check`, `validate`, `plan`, and posts the plan output as a PR comment |
| Push/merge to `main` | `fmt-and-validate` → `apply` | Runs `terraform apply -auto-approve` (gated by the `production` environment if you configured required reviewers) |
| Manual | `workflow_dispatch` | Run any job on demand from the Actions tab |

## 4. Cost note

`single_nat_gateway = true` (default) uses one NAT Gateway for both AZs to
keep this cheap for learning (~$0.045/hr + data). Set it to `false` for a
production-realistic, fully HA setup — one NAT Gateway per AZ, roughly double
the cost. Always `terraform destroy` when you're done experimenting.

## 5. What to try next

- Break the NACL rule in `security.tf` (e.g. remove the ephemeral port rule)
  and watch SSH into the app instance from the bastion start failing — great
  way to feel the stateless-vs-stateful distinction from the notes.
- Flip `single_nat_gateway` to `false` and re-apply to see the HA topology.
- Add a `aws_s3_bucket` resource named to match the IAM policy in `iam.tf`
  and test `aws s3 ls` from inside the app instance using its instance role
  — no access keys involved.
