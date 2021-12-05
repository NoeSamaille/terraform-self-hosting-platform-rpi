################################################
# Deploy MetalLB in Kubernetes
################################################


resource "helm_release" "metallb" {
  name       = "metallb"
  namespace  = "kube-system"
  repository = "https://charts.helm.sh/stable"
  chart      = "metallb"
  #version      = "2.5.13"

  set {
    name  = "configInline.address-pools[0].name"
    value = "default"
    type  = "string"
  }

  set {
    name  = "configInline.address-pools[0].protocol"
    value = "layer2"
    type  = "string"
  }

  set {
    name  = "configInline.address-pools[0].addresses[0]"
    value = var.metallb_addresses
    type  = "string"
  }
}


################################################
# Deploy nginx ingress controller in Kubernetes
################################################


resource "helm_release" "nginx_ingress_controller" {
  depends_on = [
    helm_release.metallb
  ]
  name       = "nginx-ingress"
  namespace  = "kube-system"
  repository = "https://charts.helm.sh/stable"
  chart      = "nginx-ingress"
  #version      = "9.0.9"

  set {
    name  = "defaultBackend.enabled"
    value = "false"
  }
}


################################################
# Deploy cert-manager in Kubernetes
################################################

resource "helm_release" "cert_manager" {
  depends_on = [
    helm_release.nginx_ingress_controller,
  ]
  name       = "cert-manager"
  namespace  = "kube-system"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v0.16.0"
}


################################################
# Deploy certificate issuers in Kubernetes
################################################


resource "kubernetes_manifest" "clusterissuer_letsencrypt_staging" {
  depends_on = [
    helm_release.cert_manager
  ]
  manifest = {
    "apiVersion" = "cert-manager.io/v1alpha2"
    "kind"       = "ClusterIssuer"
    "metadata" = {
      "name" = "letsencrypt-staging"
    }
    "spec" = {
      "acme" = {
        "email" = var.cert_manager_issuer_email
        "privateKeySecretRef" = {
          "name" = "letsencrypt-staging"
        }
        "server" = "https://acme-staging-v02.api.letsencrypt.org/directory"
        "solvers" = [
          {
            "http01" = {
              "ingress" = {
                "class" = "nginx"
              }
            }
          },
        ]
      }
    }
  }
}
resource "kubernetes_manifest" "clusterissuer_letsencrypt_prod" {
  depends_on = [
    helm_release.cert_manager
  ]
  manifest = {
    "apiVersion" = "cert-manager.io/v1alpha2"
    "kind"       = "ClusterIssuer"
    "metadata" = {
      "name" = "letsencrypt-prod"
    }
    "spec" = {
      "acme" = {
        "email" = var.cert_manager_issuer_email
        "privateKeySecretRef" = {
          "name" = "letsencrypt-prod"
        }
        "server" = "https://acme-v02.api.letsencrypt.org/directory"
        "solvers" = [
          {
            "http01" = {
              "ingress" = {
                "class" = "nginx"
              }
            }
          },
        ]
      }
    }
  }
}


################################################
# Deploy kubernetes-dashboard in Kubernetes
################################################


resource "helm_release" "kubernetes_dashboard" {
  depends_on = [
    helm_release.nginx_ingress_controller
  ]
  name             = "kubernetes-dashboard"
  namespace        = "kubernetes-dashboard"
  create_namespace = "true"
  repository       = "https://kubernetes.github.io/dashboard"
  chart            = "kubernetes-dashboard"
  #version      = "5.0.4"

  values = [
    "${file("values/dashboard.values.yaml")}"
  ]

  set {
    name  = "ingress.hosts[0]"
    value = "dashboard.${var.domain}"
  }
  set {
    name  = "ingress.tls[0].hosts[0]"
    value = "dashboard.${var.domain}"
  }
}

# Create admin-user to connect kubernetes-dashboard
resource "kubernetes_manifest" "serviceaccount_kubernetes_dashboard_admin_user" {
  depends_on = [
    helm_release.kubernetes_dashboard
  ]
  manifest = {
    "apiVersion" = "v1"
    "kind"       = "ServiceAccount"
    "metadata" = {
      "name"      = "admin-user"
      "namespace" = "kubernetes-dashboard"
    }
  }
}
resource "kubernetes_manifest" "clusterrolebinding_admin_user" {
  depends_on = [
    helm_release.kubernetes_dashboard
  ]
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind"       = "ClusterRoleBinding"
    "metadata" = {
      "name" = "admin-user"
    }
    "roleRef" = {
      "apiGroup" = "rbac.authorization.k8s.io"
      "kind"     = "ClusterRole"
      "name"     = "cluster-admin"
    }
    "subjects" = [
      {
        "kind"      = "ServiceAccount"
        "name"      = "admin-user"
        "namespace" = "kubernetes-dashboard"
      },
    ]
  }
}
# NOTE to retrieve the unique access token of admin-user: kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}')


################################################
# Deploy bitwarden in Kubernetes
################################################


resource "kubernetes_namespace" "bitwarden_ns" {
  depends_on = [
    kubernetes_manifest.clusterissuer_letsencrypt_prod
  ]
  metadata {
    annotations = {
      name = "bitwarden"
    }

    name = "bitwarden"
  }
}
resource "kubernetes_persistent_volume" "bitwarden_pv" {
  depends_on = [
    kubernetes_namespace.bitwarden_ns
  ]
  metadata {
    labels = {
      type = "local"
    }
    name = "bitwarden"
  }
  spec {
    access_modes = [
      "ReadWriteOnce",
    ]
    capacity = {
      storage = "1Gi"
    }
    persistent_volume_source {
      host_path {
        path = var.bitwarden_host_path
      }
    }
    storage_class_name = "manual"
  }
}
resource "kubernetes_persistent_volume_claim" "bitwarden_pvc" {
  depends_on = [
    kubernetes_persistent_volume.bitwarden_pv
  ]
  metadata {
    name      = "bitwarden"
    namespace = "bitwarden"
  }
  spec {
    access_modes = [
      "ReadWriteOnce",
    ]
    resources {
      requests = {
        "storage" = "1Gi"
      }
    }
    storage_class_name = "manual"
  }
}
data "external" "bitwarden_admin_token" {
  program = ["${path.module}/token.sh"]
}
resource "helm_release" "bitwarden-k8s" {
  depends_on = [
    kubernetes_persistent_volume_claim.bitwarden_pvc
  ]
  name      = "bitwarden-k8s"
  namespace = "bitwarden"
  chart     = "charts/bitwarden-k8s"
  timeout   = 600
  wait      = true
  #version      = "5.0.4"

  values = [
    "${file("values/bitwarden-k8s.values.yaml")}"
  ]

  set {
    name  = "env.SIGNUPS_ALLOWED"
    value = var.bitwarden_signups_allowed
  }
  set {
    name  = "env.INVITATIONS_ALLOWED"
    value = var.bitwarden_invitations_allowed
  }
  set {
    name  = "env.ADMIN_TOKEN"
    value = data.external.bitwarden_admin_token.result.token
  }
  set {
    name  = "env.SERVER_ADMIN_EMAIL"
    value = var.bitwarden_server_admin_email
  }
  set {
    name  = "env.DOMAIN"
    value = "https://bitwarden.${var.domain}"
  }
  set {
    name  = "env.SMTP_HOST"
    value = var.bitwarden_smtp_host
  }
  set {
    name  = "env.SMTP_FROM"
    value = var.bitwarden_smtp_from
  }
  set {
    name  = "env.SMTP_PORT"
    value = var.bitwarden_smtp_port
  }
  set {
    name  = "env.SMTP_SSL"
    value = var.bitwarden_smtp_ssl
  }
  set {
    name  = "env.SMTP_USERNAME"
    value = var.bitwarden_smtp_username
  }
  set {
    name  = "env.SMTP_PASSWORD"
    value = var.bitwarden_smtp_password
  }
  set {
    name  = "ingress.hosts[0]"
    value = "bitwarden.${var.domain}"
  }
  set {
    name  = "ingress.tls[0].hosts[0]"
    value = "bitwarden.${var.domain}"
  }
}


################################################
# Deploy Node-RED in Kubernetes
################################################


resource "kubernetes_namespace" "node_red_ns" {
  depends_on = [
    kubernetes_manifest.clusterissuer_letsencrypt_prod
  ]
  metadata {
    annotations = {
      name = "node-red"
    }

    name = "node-red"
  }
}
resource "kubernetes_persistent_volume" "node_red_pv" {
  depends_on = [
    kubernetes_namespace.node_red_ns
  ]
  metadata {
    labels = {
      type = "local"
    }
    name = "node-red"
  }
  spec {
    access_modes = [
      "ReadWriteOnce",
    ]
    capacity = {
      storage = "5Gi"
    }
    persistent_volume_source {
      host_path {
        path = var.node_red_host_path
      }
    }
    storage_class_name = "manual"
  }
}
resource "kubernetes_persistent_volume_claim" "node_red_pvc" {
  depends_on = [
    kubernetes_persistent_volume.node_red_pv
  ]
  metadata {
    name      = "node-red"
    namespace = "node-red"
  }
  spec {
    access_modes = [
      "ReadWriteOnce",
    ]
    resources {
      requests = {
        "storage" = "5Gi"
      }
    }
    storage_class_name = "manual"
  }
}
resource "helm_release" "node_red" {
  depends_on = [
    kubernetes_persistent_volume_claim.node_red_pvc
  ]
  name       = "node-red"
  namespace  = "node-red"
  repository = "https://k8s-at-home.com/charts"
  chart      = "node-red"
  #version      = "9.1.0"

  values = [
    "${file("values/node-red.values.yaml")}"
  ]

  set {
    name  = "ingress.main.hosts[0].host"
    value = "node-red.${var.domain}"
  }
  set {
    name  = "ingress.main.tls[0].hosts[0]"
    value = "node-red.${var.domain}"
  }
}
