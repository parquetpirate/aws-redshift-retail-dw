# Retail Data Warehouse on AWS Redshift

A cloud data warehouse for retail sales analytics, provisioned end-to-end with Terraform and loaded into Amazon Redshift. The project covers infrastructure as code, a star-schema dimensional model, bulk loading from S3, and BI exploration with Metabase.

## Tech Stack

![Terraform](https://img.shields.io/badge/Terraform-844FBA?style=flat&logo=terraform&logoColor=white)
![Amazon Redshift](https://img.shields.io/badge/Amazon%20Redshift-8C4FFF?style=flat&logo=amazonredshift&logoColor=white)
![Amazon S3](https://img.shields.io/badge/Amazon%20S3-569A31?style=flat&logo=amazons3&logoColor=white)
![AWS IAM](https://img.shields.io/badge/AWS%20IAM-FF9900?style=flat&logo=amazoniam&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/psql-4169E1?style=flat&logo=postgresql&logoColor=white)
![Metabase](https://img.shields.io/badge/Metabase-509EE3?style=flat&logo=metabase&logoColor=white)

## Overview

**Problem solved:** turns flat retail sales CSVs into a queryable star-schema warehouse on Redshift, with the underlying infrastructure fully reproducible from code instead of clicked together in the AWS console.

## Architecture

![Architecture diagram: a local Docker container applies Terraform to provision a Redshift VPC (subnet, internet gateway, route table, security group, Redshift cluster) and an IAM role in AWS, then loads the schema via psql; the Redshift cluster assumes the IAM role to read from an S3 bucket via COPY, and Metabase queries the cluster over port 5439](assets/diagrams/architecture.png)

Everything under `terraform/infrastructure` is applied from a disposable Docker container (Terraform + AWS CLI + `psql`), so the workflow needs no local tooling beyond Docker.

**Component details:**

| Component | Resource | Purpose |
|---|---|---|
| Networking | `aws_vpc`, `aws_subnet`, `aws_internet_gateway`, `aws_route_table` | Isolated network for the cluster, with a route to the internet |
| Access control | `aws_security_group` (`redshift_sg`) | Restricts inbound traffic on port 5439 to `allowed_cidr` |
| Data warehouse | `aws_redshift_cluster` (`redshift-cluster`) | RA3 single-node Redshift cluster, publicly accessible, database `db` |
| S3 access | `aws_iam_role` (`RedshiftS3AccessRole`) + `AmazonS3ReadOnlyAccess` policy | Lets Redshift run `COPY` from the staging S3 bucket without embedding credentials |
| Runtime | `Dockerfile` | Ubuntu image with Terraform 1.15.8, AWS CLI v2, and `postgresql-contrib` (`psql`) |

## Dimensional model

Star schema with one fact table and four dimensions, defined in `terraform/database/physical_model.sql`:

| Table | Grain / attributes |
|---|---|
| `dw.fact_sales` | One row per product × customer × location × time; `quantity`, `unit_price`, `product_cost`, `sales_revenue` |
| `dw.dim_customer` | `customer_id`, `customer_name`, `customer_type` (Corporate / Consumer) |
| `dw.dim_product` | `product_id`, `product_name`, `category`, `subcategory` |
| `dw.dim_location` | `location_id`, `country`, `region`, `state`, `city` |
| `dw.dim_time` | `full_date`, `year`, `month`, `day` |

All dimension surrogate keys (`*_sk`) are referenced as foreign keys on `dw.fact_sales`. Conceptual, dimensional, and logical model diagrams are in `docs/` (kept local only — gitignored, not published to this repo).

## Data flow

![Data flow diagram: CSV files are uploaded to an S3 bucket, then COPY commands load the four dimension tables (dw.dim_customer, dw.dim_location, dw.dim_product, dw.dim_time) and dw.fact_sales from S3; the dimension tables feed into dw.fact_sales, which is queried by Metabase](assets/diagrams/data-flow.png)

1. Source CSVs in `data/` are uploaded to an S3 staging bucket under a `data/` prefix.
2. `physical_model.sql` creates the `dw` schema and the five tables (`CREATE TABLE IF NOT EXISTS`).
3. Each table is bulk-loaded with a `COPY ... IAM_ROLE 'arn:aws:iam::<account>:role/RedshiftS3AccessRole' CSV` statement — Redshift reads directly from S3 using the IAM role, no credentials in the SQL file.
4. `dw.fact_sales` is loaded last, since it holds foreign keys to all four dimensions.
5. Metabase connects to the cluster over port 5439 and queries the star schema for reporting.

## Repository structure

```
.
├── Dockerfile                      # Terraform + AWS CLI + psql image
├── assets/diagrams/                # Architecture and data flow diagrams (PNG, made with Eraser)
├── data/                           # Source CSVs loaded into Redshift (dim_*, fact_sales)
└── terraform/
    ├── infrastructure/             # VPC, Redshift cluster, IAM role (Terraform)
    │   ├── provider.tf             # AWS provider, us-east-2
    │   ├── variables.tf            # db_master_password, allowed_cidr
    │   ├── main.tf                 # VPC, subnet, IGW, route table, security group, Redshift cluster
    │   ├── iam.tf                  # RedshiftS3AccessRole
    │   └── terraform.tfvars.example
    └── database/
        └── physical_model.sql      # Schema DDL + COPY commands from S3
```

## Prerequisites

- Docker
- An AWS account with permissions to create VPC, IAM, and Redshift resources
- An S3 bucket in `us-east-2` to stage the source CSVs

## Deployment

1. **Create an S3 staging bucket** in `us-east-2` and upload the contents of `data/` into a `data/` prefix inside it (e.g. `s3://your-bucket/data/dim_customer.csv`).

2. **Build the Docker image:**

   ```bash
   docker build -t image-terraform:redshift .
   ```

3. **Run the container**, mounting the `terraform/` folder:

   ```bash
   docker run -dit --name aws-rd -v "$(pwd)/terraform":/iac image-terraform:redshift /bin/bash
   docker exec -it aws-rd /bin/bash
   ```

4. **Configure AWS credentials** inside the container:

   ```bash
   aws configure
   ```

5. **Set the Terraform variables.** Copy the example file and fill in your own values — never commit the real file:

   ```bash
   cd /iac/infrastructure
   cp terraform.tfvars.example terraform.tfvars
   # edit terraform.tfvars: set db_master_password and allowed_cidr (your public IP, e.g. 203.0.113.10/32)
   ```

   Alternatively, skip the file entirely and pass values as environment variables:

   ```bash
   export TF_VAR_db_master_password="a-strong-password"
   export TF_VAR_allowed_cidr="$(curl -s ifconfig.me)/32"
   ```

6. **Provision the infrastructure:**

   ```bash
   terraform init
   terraform validate
   terraform plan
   terraform apply
   ```

   This creates the VPC, subnet, internet gateway, route table, a security group locked to `allowed_cidr` on port 5439, the Redshift cluster, and an IAM role (`RedshiftS3AccessRole`) with S3 read-only access.

7. **Load the schema and data.** Edit `terraform/database/physical_model.sql`, replacing `<YOUR_BUCKET_NAME>` and `<YOUR_AWS_ACCOUNT_ID>` with your own values, then run it against the cluster endpoint (found in the Redshift console or via `terraform output` if configured):

   ```bash
   cd /iac/database
   psql -h <cluster-endpoint> -U adminuser -d db -p 5439 -f physical_model.sql
   ```

8. **Explore with Metabase:**

   ```bash
   docker run -d -p 3000:3000 --name metabase metabase/metabase
   ```

   Open `http://localhost:3000`, connect it to the Redshift cluster, and build reports. Example query:

   ```sql
   SELECT
       p.product_name,
       p.category,
       p.subcategory,
       SUM(f.sales_revenue) AS total_revenue
   FROM dw.fact_sales f
   JOIN dw.dim_product p ON f.product_sk = p.product_sk
   GROUP BY p.product_name, p.category, p.subcategory
   ORDER BY total_revenue DESC;
   ```

## Security considerations

| Aspect | Implementation |
|---|---|
| Network exposure | Cluster is `publicly_accessible = true`, but inbound access on port 5439 is restricted by `redshift_sg` to `allowed_cidr` only — never set this to `0.0.0.0/0` |
| Credentials | `db_master_password` and `allowed_cidr` are Terraform variables (one marked `sensitive`), never hardcoded; `terraform.tfvars` and all `*.tfstate` files are gitignored |
| S3 access | Redshift reads staged CSVs via `RedshiftS3AccessRole` (`AmazonS3ReadOnlyAccess`), so no AWS access keys are embedded in `physical_model.sql` |
| Sensitive placeholders | `physical_model.sql` uses `<YOUR_BUCKET_NAME>` / `<YOUR_AWS_ACCOUNT_ID>` placeholders — fill in locally, don't commit real values |
| Model docs | `docs/` (conceptual/dimensional/logical diagrams) is gitignored and stays local, not published to this repo |

## Teardown

```bash
cd /iac/infrastructure
terraform destroy
```

This tears down the Redshift cluster and all networking resources to avoid ongoing AWS charges.

## Future Improvements

- [ ] Multi-node Redshift cluster with distribution/sort keys tuned per table for larger datasets
- [ ] Automate the S3 upload and `COPY` step (currently manual) with a script or a small orchestration tool
- [ ] Expose `terraform output` for the cluster endpoint instead of looking it up in the console
- [ ] Restrict `publicly_accessible` and access the cluster through a VPN/bastion instead of a public CIDR

## Lessons Learned

- RA3 node types decouple compute from storage, which makes `ra3.large` viable even for a single-node, low-volume warehouse like this one — earlier DC2 node types would tie storage growth directly to compute cost.
- Redshift's `COPY ... IAM_ROLE` avoids ever putting AWS access keys in SQL files or version control — the role is attached to the cluster itself and assumed at load time.
- Loading `dw.fact_sales` last matters: its foreign keys reference all four dimension tables, so loading it first would fail (or silently skip constraint checks depending on load options).
- Keeping `docs/` gitignored while still documenting the model in the README (as a table) avoids publishing exported diagram files while keeping the schema itself discoverable from the repo alone.
