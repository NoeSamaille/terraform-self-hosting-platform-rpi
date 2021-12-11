
################################################
# Deploy MetalLB in Kubernetes
################################################


resource "helm_release" "metallb" {
  name       = "metallb"
  namespace  = "kube-system"
  repository = "https://charts.helm.sh/stable"
  chart      = "metallb"
  #version      = "2.5.13"
  timeout     = 600
  wait        = true

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
    value = "${var.metallb_addresses_first}-${var.metallb_addresses_last}"
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
  timeout     = 600
  wait        = true

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
  timeout     = 600
  wait        = true
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
    kubernetes_manifest.clusterissuer_letsencrypt_staging,
    helm_release.nginx_ingress_controller
  ]
  name             = "kubernetes-dashboard"
  namespace        = "kubernetes-dashboard"
  create_namespace = true
  repository       = "https://kubernetes.github.io/dashboard"
  chart            = "kubernetes-dashboard"
  #version      = "5.0.4"
  timeout     = 600
  wait        = true

  values = [
    "${file("values/dashboard.values.yaml")}"
  ]

  set {
    name  = "ingress.hosts[0]"
    value = "kubernetes-dashboard.${var.domain}"
  }
  set {
    name  = "ingress.tls[0].hosts[0]"
    value = "kubernetes-dashboard.${var.domain}"
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
    kubernetes_manifest.serviceaccount_kubernetes_dashboard_admin_user
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
data "external" "dashboard_admin_token" {
  depends_on = [
    kubernetes_manifest.clusterrolebinding_admin_user
  ]
  program = ["${path.module}/scripts/dashboard-admin-token.sh"]
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
resource "helm_release" "bitwarden" {
  depends_on = [
    kubernetes_persistent_volume_claim.bitwarden_pvc
  ]
  name             = "bitwarden"
  namespace        = "bitwarden"
  repository       = "https://k8s-at-home.com/charts"
  chart            = "vaultwarden"
  #version      = "3.3.1"
  timeout     = 600
  wait        = true

  values = [
    "${file("values/vaultwarden.values.yaml")}"
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
    value = var.bitwarden_admin_token
  }
  set {
    name  = "env.SERVER_ADMIN_EMAIL"
    value = var.bitwarden_server_admin_email
  }
  set {
    name  = "env.DOMAIN"
    value = "https://vault.${var.domain}"
  }
  set {
    name  = "env.SMTP_HOST"
    value = var.smtp_host
  }
  set {
    name  = "env.SMTP_FROM"
    value = var.smtp_from
  }
  set {
    name  = "env.SMTP_PORT"
    value = var.smtp_port
  }
  set {
    name  = "env.SMTP_SSL"
    value = var.smtp_ssl
  }
  set {
    name  = "env.SMTP_USERNAME"
    value = var.smtp_username
  }
  set {
    name  = "env.SMTP_PASSWORD"
    value = var.smtp_password
  }
  set {
    name  = "ingress.main.hosts[0].host"
    value = "vault.${var.domain}"
  }
  set {
    name  = "ingress.main.tls[0].hosts[0]"
    value = "vault.${var.domain}"
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
  timeout     = 600
  wait        = true

  values = [
    "${file("values/node-red.values.yaml")}"
  ]

  set {
    name  = "ingress.main.hosts[0].host"
    value = "flows.${var.domain}"
  }
  set {
    name  = "ingress.main.tls[0].hosts[0]"
    value = "flows.${var.domain}"
  }
}


################################################
# Deploy Nextcloud in Kubernetes
################################################


resource "kubernetes_namespace" "nextcloud_ns" {
  depends_on = [
    kubernetes_manifest.clusterissuer_letsencrypt_prod
  ]
  metadata {
    annotations = {
      name = "nextcloud"
    }

    name = "nextcloud"
  }
}
resource "kubernetes_persistent_volume" "nextcloud_app_pv" {
  depends_on = [
    kubernetes_namespace.nextcloud_ns
  ]
  metadata {
    labels = {
      type = "local"
    }
    name = "nextcloud-app"
  }
  spec {
    access_modes = [
      "ReadWriteOnce",
    ]
    capacity = {
      storage = "30Gi"
    }
    persistent_volume_source {
      host_path {
        path = var.nextcloud_app_host_path
      }
    }
    storage_class_name = "manual"
  }
}
resource "kubernetes_persistent_volume_claim" "nextcloud_app_pvc" {
  depends_on = [
    kubernetes_persistent_volume.nextcloud_app_pv
  ]
  metadata {
    name      = "nextcloud-app"
    namespace = "nextcloud"
  }
  spec {
    access_modes = [
      "ReadWriteOnce",
    ]
    resources {
      requests = {
        "storage" = "30Gi"
      }
    }
    storage_class_name = "manual"
  }
}
resource "kubernetes_persistent_volume" "nextcloud_data_pv" {
  depends_on = [
    kubernetes_namespace.nextcloud_ns
  ]
  metadata {
    labels = {
      type = "local"
    }
    name = "nextcloud-data"
  }
  spec {
    access_modes = [
      "ReadWriteOnce",
    ]
    capacity = {
      storage = "3Ti"
    }
    persistent_volume_source {
      host_path {
        path = var.nextcloud_data_host_path
      }
    }
    storage_class_name = "manual"
  }
}
resource "kubernetes_persistent_volume_claim" "nextcloud_data_pvc" {
  depends_on = [
    kubernetes_persistent_volume.nextcloud_data_pv
  ]
  metadata {
    name      = "nextcloud-data"
    namespace = "nextcloud"
  }
  spec {
    access_modes = [
      "ReadWriteOnce",
    ]
    resources {
      requests = {
        "storage" = "3Ti"
      }
    }
    storage_class_name = "manual"
  }
}
resource "helm_release" "nextcloud" {
  depends_on = [
    kubernetes_persistent_volume_claim.nextcloud_app_pvc,
    kubernetes_persistent_volume_claim.nextcloud_data_pvc
  ]
  name        = "nextcloud"
  namespace   = "nextcloud"
  repository  = "https://nextcloud.github.io/helm"
  chart       = "nextcloud"
  timeout     = 1200
  wait        = true
  #version    = "2.10.2"

  values = [
    "${file("values/nextcloud.values.yaml")}"
  ]

  set {
    name  = "nextcloud.host"
    value = "drive.${var.domain}"
  }
  set {
    name  = "nextcloud.password"
    value = var.nextcloud_admin_password
  }
  set {
    name  = "nextcloud.mail.enabled"
    value = var.nextcloud_mail_enabled
  }
  set {
    name  = "nextcloud.mail.fromAddress"
    value = var.smtp_from
  }
  set {
    name  = "nextcloud.mail.domain"
    value = var.nextcloud_mail_domain
  }
  set {
    name  = "nextcloud.mail.smtp.host"
    value = var.smtp_host
  }
  set {
    name  = "nextcloud.mail.smtp.secure"
    value = var.smtp_ssl ? "ssl" : ""
  }
  set {
    name  = "nextcloud.mail.smtp.port"
    value = var.smtp_port
  }
  set {
    name  = "nextcloud.mail.smtp.name"
    value = var.smtp_username
  }
  set {
    name  = "nextcloud.mail.smtp.password"
    value = var.smtp_password
  }
  set {
    name  = "ingress.hosts[0].host"
    value = "drive.${var.domain}"
  }
  set {
    name  = "ingress.tls[0].hosts[0]"
    value = "drive.${var.domain}"
  }
}


################################################
# Deploy Media Center in Kubernetes
################################################

resource "kubernetes_namespace" "media_ns" {
  depends_on = [
    helm_release.nginx_ingress_controller
  ]
  metadata {
    annotations = {
      name = "media"
    }

    name = "media"
  }
}
resource "kubernetes_persistent_volume" "media_apps_pv" {
  depends_on = [
    kubernetes_namespace.media_ns
  ]
  metadata {
    labels = {
      type = "local"
    }
    name = "media-apps"
  }
  spec {
    access_modes = [
      "ReadWriteOnce",
    ]
    capacity = {
      storage = "50Gi"
    }
    persistent_volume_source {
      host_path {
        path = var.media_apps_host_path
      }
    }
    storage_class_name = "manual"
  }
}
resource "kubernetes_persistent_volume_claim" "media_apps_pvc" {
  depends_on = [
    kubernetes_persistent_volume.media_apps_pv
  ]
  metadata {
    name      = "media-apps"
    namespace = "media"
  }
  spec {
    access_modes = [
      "ReadWriteOnce",
    ]
    resources {
      requests = {
        "storage" = "50Gi"
      }
    }
    storage_class_name = "manual"
  }
}
resource "kubernetes_persistent_volume" "media_data_pv" {
  depends_on = [
    kubernetes_namespace.media_ns
  ]
  metadata {
    labels = {
      type = "local"
    }
    name = "media-data"
  }
  spec {
    access_modes = [
      "ReadWriteOnce",
    ]
    capacity = {
      storage = "2Ti"
    }
    persistent_volume_source {
      host_path {
        path = var.media_data_host_path
      }
    }
    storage_class_name = "manual"
  }
}
resource "kubernetes_persistent_volume_claim" "media_data_pvc" {
  depends_on = [
    kubernetes_persistent_volume.media_data_pv
  ]
  metadata {
    name      = "media-data"
    namespace = "media"
  }
  spec {
    access_modes = [
      "ReadWriteOnce",
    ]
    resources {
      requests = {
        "storage" = "2Ti"
      }
    }
    storage_class_name = "manual"
  }
}
resource "kubernetes_ingress" "media_ingress" {
  depends_on = [
    kubernetes_namespace.media_ns
  ]
  metadata {
    name = "media-ingress"
    namespace = "media"
    annotations = {
      "ingress.class" = "nginx"
    }
  }

  spec {

    rule {
      host = "media.${var.metallb_addresses_first}.nip.io"
      http {
        path {
          backend {
            service_name = "transmission-transmission-openvpn"
            service_port = 80
          }
          path = "/transmission"
        }
        path {
          backend {
            service_name = "sonarr"
            service_port = 80
          }
          path = "/sonarr"
        }
        path {
          backend {
            service_name = "jackett"
            service_port = 80
          }
          path = "/jackett"
        }
        path {
          backend {
            service_name = "radarr"
            service_port = 80
          }
          path = "/radarr"
        }
        path {
          backend {
            service_name = "plex-kube-plex"
            service_port = 32400
          }
          path = "/"
        }
      }
    }
  }
}
resource "kubernetes_secret" "openvpn_secret" {
  depends_on = [
    kubernetes_namespace.media_ns
  ]
  metadata {
    name = "openvpn"
    namespace = "media"
  }

  data = {
    "openvpn.ovpn" = "${file("${path.module}/openvpn.ignore.ovpn")}"
    username = var.ovpn_username
    password = var.ovpn_password
  }
}
resource "kubernetes_secret" "transmission_secret" {
  depends_on = [
    kubernetes_namespace.media_ns
  ]
  metadata {
    name = "transmission"
    namespace = "media"
  }

  data = {
    username = var.transmission_username
    password = var.transmission_password
  }
}
resource "helm_release" "transmission" {
  depends_on = [
    kubernetes_persistent_volume_claim.media_apps_pvc,
    kubernetes_persistent_volume_claim.media_data_pvc,
    kubernetes_ingress.media_ingress,
    kubernetes_secret.openvpn_secret,
    kubernetes_secret.transmission_secret,
  ]
  name        = "transmission"
  namespace   = "media"
  repository  = "https://bananaspliff.github.io/geek-charts"
  chart       = "transmission-openvpn"
  timeout     = 600
  wait        = true
  #version    = "0.1.0"

  values = [
    "${file("values/media.transmission.values.yaml")}"
  ]
}
resource "helm_release" "flaresolverr" {
  depends_on = [
    kubernetes_persistent_volume_claim.media_apps_pvc,
    kubernetes_persistent_volume_claim.media_data_pvc,
    helm_release.transmission
  ]
  name        = "flaresolverr"
  namespace   = "media"
  repository  = "https://k8s-at-home.com/charts"
  chart       = "flaresolverr"
  timeout     = 600
  wait        = true
  #version    = "5.1.0"

  values = [
    "${file("values/media.flaresolverr.values.yaml")}"
  ]
}
resource "helm_release" "jackett" {
  depends_on = [
    kubernetes_persistent_volume_claim.media_apps_pvc,
    kubernetes_persistent_volume_claim.media_data_pvc,
    helm_release.flaresolverr
  ]
  name        = "jackett"
  namespace   = "media"
  repository  = "https://bananaspliff.github.io/geek-charts"
  chart       = "jackett"
  timeout     = 600
  wait        = true
  #version    = "0.1.0"

  values = [
    "${file("values/media.jackett.values.yaml")}"
  ]
}
resource "helm_release" "radarr" {
  depends_on = [
    kubernetes_persistent_volume_claim.media_apps_pvc,
    kubernetes_persistent_volume_claim.media_data_pvc,
    helm_release.jackett
  ]
  name        = "radarr"
  namespace   = "media"
  repository  = "https://bananaspliff.github.io/geek-charts"
  chart       = "radarr"
  timeout     = 600
  wait        = true
  #version    = "0.1.0"

  values = [
    "${file("values/media.radarr.values.yaml")}"
  ]
}
resource "helm_release" "sonarr" {
  depends_on = [
    kubernetes_persistent_volume_claim.media_apps_pvc,
    kubernetes_persistent_volume_claim.media_data_pvc,
    helm_release.jackett
  ]
  name        = "sonarr"
  namespace   = "media"
  repository  = "https://bananaspliff.github.io/geek-charts"
  chart       = "sonarr"
  timeout     = 600
  wait        = true
  #version    = "0.1.0"

  values = [
    "${file("values/media.sonarr.values.yaml")}"
  ]
}
