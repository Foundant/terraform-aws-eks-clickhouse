output "eks_cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = module.eks_aws.cluster_arn
}

output "eks_cluster_endpoint" {
  description = "The endpoint for your Kubernetes API server"
  value       = module.eks_aws.cluster_endpoint
}

output "eks_cluster_name" {
  description = "The name for your Kubernetes API server"
  value       = module.eks_aws.cluster_name
}

output "eks_cluster_ca_certificate" {
  description = "The base64 encoded certificate data required to communicate with your cluster"
  value       = module.eks_aws.cluster_certificate_authority
  sensitive   = true
}

output "eks_configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${var.eks_region} update-kubeconfig --name ${module.eks_aws.cluster_name}"
}

output "clickhouse_cluster_url" {
  description = "The public URL for the ClickHouse cluster"
  value       = length(module.clickhouse_cluster) > 0 ? module.clickhouse_cluster[0].clickhouse_cluster_url : ""
}

output "clickhouse_master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret containing ClickHouse credentials"
  value       = var.clickhouse_master_user_secret_arn
}

output "cluster_node_pools" {
  value = module.eks_aws.cluster_node_pools
}

output "clickhouse_backup_s3_bucket" {
  description = "S3 bucket name for ClickHouse backups"
  value       = var.install_clickhouse_cluster ? aws_s3_bucket.clickhouse_backups[0].id : ""
}

output "clickhouse_backup_s3_bucket_arn" {
  description = "S3 bucket ARN for ClickHouse backups"
  value       = var.install_clickhouse_cluster ? aws_s3_bucket.clickhouse_backups[0].arn : ""
}
