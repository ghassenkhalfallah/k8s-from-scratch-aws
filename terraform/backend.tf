terraform {
  # Local backend — state stored in terraform.tfstate in this directory.
  # Switch to the S3 backend block below when running in a real AWS account
  # with a pre-provisioned state bucket.
  backend "local" {
    path = "terraform.tfstate"
  }

  # ── Remote backend (re-enable for production) ─────────────────────────────
  # backend "s3" {
  #   bucket       = "YOUR-BUCKET-NAME"
  #   key          = "k8s-cluster/terraform.tfstate"
  #   region       = "eu-west-1"
  #   encrypt      = true
  #   use_lockfile = true
  # }
}
