# Healthcare Data Modernization Demo (Azure DevOps + Terraform)


**Goal:** Demonstrate infra automation (Terraform) + CI/CD (Azure DevOps) for a small, healthcare‑flavored API (mock analytics endpoint), aligned to landing‑zone practices.


## What gets deployed
- Resource Group
- Storage Account (runtime for Functions)
- Application Insights (monitoring)
- **Key Vault** (stores a demo secret; Function reads it via KV reference)
- Python Azure Function App (Consumption) with an HTTP trigger
- **(Optional) Networking**: VNet + subnets + Private Endpoint for Storage (toggle)
- **Tagging** on every resource (Environment, Owner, CostCenter)
- **Governance** with Azure Policy at the RG scope:
- Require tags (deny if missing or empty)
- Audit public network access on Storage (configurable to Deny)


## Prereqs
1. Azure subscription (any; owner or contributor + user access admin)
2. Azure DevOps project + Service Connection (ARM) named `sc-azure-portfolio` (changeable)
3. Terraform backend storage (the pipeline will create if missing)


## Quick start
```bash
# Clone
git clone https://github.com/savfrydev Healthcare-Data-Modernization-Project.git
cd Healthcare-Data-Modernization-Project

# (Optional) local test of infra
cd infra
terraform init
terraform plan \
-var "location=eastus" \
-var "enable_networking=false" \
-var "tag_environment=Dev" \
-var "tag_owner=Savannah" \
-var "tag_costcenter=HCARE-POC" \
-var "governance_mode=audit"
