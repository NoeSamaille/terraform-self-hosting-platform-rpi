terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.7.0"
    }
    helm = {
      source = "hashicorp/helm"
      version = "2.4.1"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "default"
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "default"
  }
}
