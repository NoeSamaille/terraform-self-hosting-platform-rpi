# Terraform self-hosting platform on Raspberry Pi

Terraform module to deploy your own self-hosted platform on Kubernetes on Raspberry Pi.

## Roadmap

- [x] Configure Kubernetes cluster
- [x] Self-host password manager: Bitwarden
- [x] Self-host IoT dev platform: Node-RED
- [ ] Self-host home cloud: NextCloud
- [ ] Self-host Media Center: Plex, Sonarr, Radarr, Transmission and Jackett
- [ ] Self-host ads/trackers protection: Pi-Hole

## Prerequisites

- Accessible K8s/K3s cluster on your Pi.

## Usage

Configure your environment:
```sh
$ mv terraform.tfvars.template terraform.tfvars
$ vim terraform.tfvars
```

Once it's done you can start deploying resources:
```sh
$ terraform init
$ terraform plan
$ terraform apply
```