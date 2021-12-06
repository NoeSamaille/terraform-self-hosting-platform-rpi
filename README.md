# Terraform self-hosting platform on Raspberry Pi

Terraform module to deploy your own self-hosted platform on Kubernetes on Raspberry Pi.

## Roadmap

- [x] Configure Kubernetes cluster
- [x] Self-host password manager: Bitwarden
- [x] Self-host IoT dev platform: Node-RED
- [x] Self-host home cloud: NextCloud
- [ ] Self-host Media Center: Plex, Sonarr, Radarr, Transmission and Jackett
- [ ] Self-host ads/trackers protection: Pi-Hole

## Prerequisites

- Accessible K8s/K3s cluster on your Pi.
  - With `cert-manager` CustomResourceDefinition installed: `kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.16.0/cert-manager.crds.yaml`

## Usage

Configure your environment:
```sh
$ mv terraform.tfvars.template terraform.tfvars
$ vim terraform.tfvars
```

Once it's done you can start deploying resources:
```sh
$ source scripts/init.sh # Generates admin passwords for bitwarden and nextcloud
$ terraform init
$ terraform apply
```

## How to set up nodes

### Base pi set up

**Note**: here we'll set up `pi-master` i.e. our master pi, if you have additionnal workers (optionnal) you'll then have to repeat the following steps for each of the workers, replacing references to `pi-master` by `pi-worker-1`, `pi-worker-2`, etc.

1. Connect via SSH to the pi:
    ```sh
    user@workstation $ ssh pi@<PI_IP>
    ... output ommited ...
    pi@raspberrypi:~ $
    ```
2. Change password:
    ```sh
    pi@raspberrypi:~ $ passwd
    ... output ommited ...
    passwd: password updated successfully
    ```
3. Change hostnames:
    ```sh
    pi@raspberrypi:~ $ sudo -i
    root@raspberrypi:~ $ echo "pi-master" > /etc/hostname
    root@raspberrypi:~ $ sed -i "s/$HOSTNAME/pi-master/" /etc/hosts
    ```
4. Enable container features:
    ```sh
    root@raspberrypi:~ $ sed -i 's/$/ cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory/' /boot/cmdline.txt
    ```
5. Make sure the system is up-to-date:
    ```sh
    root@raspberrypi:~ $ apt update && apt upgrade -y
    ```
6. Configure a static IP, **Note** that This could be also done at the network level via the router admin (DHCP):
    ```sh
    root@raspberrypi:~ $ cat <<EOF >> /etc/dhcpcd.conf
    interface eth0
    static ip_address=<YOUR_STATIC_IP_HERE>/24
    static routers=192.168.1.1
    static domain_name_servers=1.1.1.1
    EOF
    ```
7. Reboot:
    ```sh
    root@raspberrypi:~ $ reboot
    ```
8. Wait for a few sec, then connect via SSH to the pi using the new static IP you've just configured:
    ```sh
    user@workstation $ ssh pi@<PI_IP>
    ... output ommited ...
    pi@pi-master:~ $ 
    ```

### OPTIONNAL: Set up NFS disk share

#### Create NFS Share on Master Pi

1. On master pi, run the command `fdisk -l` to list all the connected disks to the system (includes the RAM) and try to identify the disk.
    ```sh
    pi@pi-master:~ $ sudo fdisk -l
    ```
2. If your disk is new and freshly out of the package, you will need to create a partition.
    ```sh
    pi@pi-master:~ $ sudo mkfs.ext4 /dev/sda 
    ```
3. You can manually mount the disk to the directory `/mnt/hdd`.
    ```sh
    pi@pi-master:~ $ sudo mkdir /mnt/hdd
    pi@pi-master:~ $ sudo chown -R pi:pi /mnt/hdd/
    pi@pi-master:~ $ sudo mount /dev/sda /mnt/hdd
    ```
4. To automatically mount the disk on startup, you first need to find the Unique ID of the disk using the command `blkid`:
    ```sh
    pi@pi-master:~ $ sudo blkid

    ... output ommited ...
    /dev/sda: UUID="0ac98c2c-8c32-476b-9009-ffca123a2654" TYPE="ext4"
    ```
5. Edit the file `/etc/fstab` and add the following line to configure auto-mount of the disk on startup:
    ```sh
    pi@pi-master:~ $ sudo -i
    root@pi-master:~ $ echo "UUID=0ac98c2c-8c32-476b-9009-ffca123a2654 /mnt/hdd ext4 defaults 0 0" >> /etc/fstab
    root@pi-master:~ $ exit
    ```
6. Reboot the system
    ```sh
    pi@pi-master:~ $ sudo reboot
    ```
7. Verify the disk is correctly mounted on startup with the following command:
    ```sh
    pi@pi-master:~ $ df -ha /dev/sda

    Filesystem      Size  Used Avail Use% Mounted on
    /dev/sda        458G   73M  435G   1% /mnt/hdd
    ```
8. Install the required dependencies:
    ```sh
    pi@pi-master:~ $ sudo apt install nfs-kernel-server -y
    ```
9. Edit the file `/etc/exports` by running the following command:
    ```sh
    pi@pi-master:~ $ sudo -i
    root@pi-master:~ $ echo "/mnt/hdd-2 *(rw,no_root_squash,insecure,async,no_subtree_check,anonuid=1000,anongid=1000)" >> /etc/exports
    root@pi-master:~ $ exit
    ```
10. Start the NFS Server:
    ```sh
    pi@pi-master:~ $ sudo exportfs -ra
    ```

#### Mount NFS share on Worker(s)

**Note**: repeat the following steps for each of the workers `pi-worker-1`, `pi-worker-2`, etc.

1. Install the necessary dependencies:
    ```sh
    pi@pi-worker-x:~ $ sudo apt install nfs-common -y
    ```
2. Create the directory to mount the NFS Share:
    ```sh
    pi@pi-worker-x:~ $ sudo mkdir /mnt/hdd
    pi@pi-worker-x:~ $ sudo chown -R pi:pi /mnt/hdd
    ```
3. Configure auto-mount of the NFS Share by adding the following line, where `<MASTER_IP>:/mnt/hdd` is the IP of `pi-master` followed by the NFS share path:
    ```sh
    pi@pi-worker-x:~ $ sudo -i
    root@pi-worker-x:~ $ echo "<MASTER_IP>:/mnt/hdd   /mnt/hdd   nfs    rw  0  0" >> /etc/fstab
    root@pi-worker-x:~ $ exit
    ```
4. Reboot the system
    ```sh
    pi@pi-worker-x:~ $ sudo reboot
    ```
5. **Optionnal**: to mount manually you can run the following command, where `<MASTER_IP>:/mnt/hdd` is the IP of `pi-master` followed by the NFS share path:
    ```sh
    pi@pi-worker-x:~ $ sudo mount -t nfs <MASTER_IP>:/mnt/hdd /mnt/hdd
    ```

### Setup K3s

#### Start K3s on Master pi

```sh
pi@pi-master:~ $ export K3S_KUBECONFIG_MODE="644"
pi@pi-master:~ $ export INSTALL_K3S_EXEC=" --no-deploy servicelb --no-deploy traefik"
pi@pi-master:~ $ curl -sfL https://get.k3s.io | sh -
```

#### Register workers

1. Get K3s token on master pi, copy the result:
    ```sh
    pi@pi-master:~ $ sudo cat /var/lib/rancher/k3s/server/node-token
    ```
2. Run K3s installer on worker (repeat on each worker):
```sh
pi@pi-worker-x:~ $ export K3S_KUBECONFIG_MODE="644"
pi@pi-worker-x:~ $ export K3S_URL="https://<MASTER_IP>:6443"
pi@pi-worker-x:~ $ export K3S_TOKEN="K103166a17...eebca269271"
pi@pi-worker-x:~ $ curl -sfL https://get.k3s.io | sh -
```

#### Access K3s cluser from workstation

1. Copy kube config file from master pi:
    ```sh
    user@workstation:~ $ scp pi@<MASTER_IP>:/etc/rancher/k3s/k3s.yaml ~/.kube/config
    ```
2. Edit kube config file to replace `127.0.0.1` with `<MASTER_IP>`:
    ```sh
    user@workstation:~ $ vim ~/.kube/config
    ```
3. Test everything by running a `kubectl` command:
    ```sh
    user@workstation:~ $ kubectl get nodes -o wide
    ```
