locals {
  eks_get_token_args = var.aws_profile != null ? ["eks", "get-token", "--cluster-name", var.eks_cluster_name, "--region", var.eks_region, "--profile", var.aws_profile] : ["eks", "get-token", "--cluster-name", var.eks_cluster_name, "--region", var.eks_region]
}

provider "kubernetes" {
  host                   = module.eks_aws.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_aws.cluster_certificate_authority)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = local.eks_get_token_args
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks_aws.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_aws.cluster_certificate_authority)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = local.eks_get_token_args
      command     = "aws"
    }
  }
}

provider "aws" {
  region = var.eks_region
}

module "eks_aws" {
  source = "./eks"

  region              = var.eks_region
  cluster_name        = var.eks_cluster_name
  cidr                = var.eks_cidr
  public_cidr         = var.eks_public_cidr
  public_access_cidrs = var.eks_public_access_cidrs
  private_cidr        = var.eks_private_cidr
  availability_zones  = var.eks_availability_zones
  cluster_version     = var.eks_cluster_version
  autoscaler_version  = var.eks_autoscaler_version
  autoscaler_replicas = var.autoscaler_replicas
  node_pools          = var.eks_node_pools
  tags                = var.eks_tags
  enable_nat_gateway  = var.eks_enable_nat_gateway
}

module "clickhouse_operator" {
  depends_on = [module.eks_aws]
  count      = var.install_clickhouse_operator ? 1 : 0
  source     = "./clickhouse-operator"

  clickhouse_operator_namespace = var.clickhouse_operator_namespace
  clickhouse_operator_version   = var.clickhouse_operator_version
}

module "clickhouse_cluster" {
  depends_on = [module.eks_aws, module.clickhouse_operator]
  count      = var.install_clickhouse_cluster ? 1 : 0
  source     = "./clickhouse-cluster"

  clickhouse_cluster_name                = var.clickhouse_cluster_name
  clickhouse_cluster_namespace           = var.clickhouse_cluster_namespace
  clickhouse_cluster_password            = var.clickhouse_cluster_password
  clickhouse_cluster_user                = var.clickhouse_cluster_user
  clickhouse_cluster_instance_type       = var.eks_node_pools[0].instance_type
  clickhouse_cluster_enable_loadbalancer = var.clickhouse_cluster_enable_loadbalancer
  clickhouse_cluster_chart_version       = var.clickhouse_cluster_chart_version
  clickhouse_keeper_chart_version        = var.clickhouse_keeper_chart_version
  clickhouse_version                     = var.clickhouse_version

  k8s_availability_zones            = var.eks_availability_zones
  k8s_cluster_region                = var.eks_region
  k8s_cluster_name                  = var.eks_cluster_name
  k8s_cluster_endpoint              = module.eks_aws.cluster_endpoint
  k8s_cluster_certificate_authority = base64decode(module.eks_aws.cluster_certificate_authority)
}
