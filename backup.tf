# S3 bucket for ClickHouse backups
resource "aws_s3_bucket" "clickhouse_backups" {
  count  = var.install_clickhouse_cluster ? 1 : 0
  bucket = "${var.eks_cluster_name}-clickhouse-backups-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.eks_tags, {
    Purpose = "ClickHouse backups"
    Cluster = var.eks_cluster_name
  })
}

resource "aws_s3_bucket_versioning" "clickhouse_backups" {
  count  = var.install_clickhouse_cluster ? 1 : 0
  bucket = aws_s3_bucket.clickhouse_backups[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "clickhouse_backups" {
  count  = var.install_clickhouse_cluster ? 1 : 0
  bucket = aws_s3_bucket.clickhouse_backups[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "clickhouse_backups" {
  count  = var.install_clickhouse_cluster ? 1 : 0
  bucket = aws_s3_bucket.clickhouse_backups[0].id

  rule {
    id     = "expire-old-backups"
    status = "Enabled"

    expiration {
      days = var.clickhouse_backup_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# IAM policy for ClickHouse backup operator
resource "aws_iam_policy" "clickhouse_backup_s3" {
  count       = var.install_clickhouse_cluster ? 1 : 0
  name        = "${var.eks_cluster_name}-clickhouse-backup-s3"
  description = "Policy for ClickHouse backup operator to access S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = aws_s3_bucket.clickhouse_backups[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.clickhouse_backups[0].arn}/*"
      }
    ]
  })
}

# IAM role for ClickHouse backup operator
resource "aws_iam_role" "clickhouse_backup" {
  count = var.install_clickhouse_cluster ? 1 : 0
  name  = "${var.eks_cluster_name}-clickhouse-backup"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(module.eks_aws.cluster_oidc_issuer_url, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(module.eks_aws.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:${var.clickhouse_cluster_namespace}:clickhouse-backup"
            "${replace(module.eks_aws.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "clickhouse_backup" {
  count      = var.install_clickhouse_cluster ? 1 : 0
  policy_arn = aws_iam_policy.clickhouse_backup_s3[0].arn
  role       = aws_iam_role.clickhouse_backup[0].name
}

# Kubernetes service account for backup operator
resource "kubernetes_service_account" "clickhouse_backup" {
  count = var.install_clickhouse_cluster ? 1 : 0

  metadata {
    name      = "clickhouse-backup"
    namespace = var.clickhouse_cluster_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.clickhouse_backup[0].arn
    }
  }

  depends_on = [module.clickhouse_cluster]
}

# Deploy Altinity ClickHouse backup operator
resource "helm_release" "clickhouse_backup" {
  count      = var.install_clickhouse_cluster ? 1 : 0
  name       = "clickhouse-backup"
  namespace  = var.clickhouse_cluster_namespace
  repository = "https://altinity.github.io/helm-charts"
  chart      = "clickhouse-backup"
  version    = var.clickhouse_backup_chart_version
  timeout    = 600

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.clickhouse_backup[0].metadata[0].name
  }

  set {
    name  = "config.s3.bucket"
    value = aws_s3_bucket.clickhouse_backups[0].id
  }

  set {
    name  = "config.s3.region"
    value = var.eks_region
  }

  set {
    name  = "config.s3.use_role_arn"
    value = "true"
  }

  depends_on = [
    module.clickhouse_cluster,
    kubernetes_service_account.clickhouse_backup
  ]
}

data "aws_caller_identity" "current" {} 