# Yandex Cloud OpenVPN

This repo contains a Terraform + Ansible recipe to create your own personal VPN server in [Yandex Cloud](https://cloud.yandex.com) located in Russia.

## Quickstep Guide

### Install deps

```sh
brew install python3
brew install terraform
brew install ansible
```

### Generate SSH Keys

This recipe assumes that you have `~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub`. If not, run:

```bash
ssh-keygen -t rsa -b 4096
```

### Prepare Yandex Cloud environment

1. Install and configure Yandex Cloud CLI (`yc`): https://cloud.yandex.com/en/docs/cli/quickstart
2. Create new empty folder in the cloud (do not create default VPC network when prompted)
3. Create new CLI profile at `~/.config/yandex-cloud/config.yaml` like so:

   ```yaml
   vpn:
     token: <YOUR_OAUTH_TOKEN>
     cloud-id: <YOUR_CLOUD_ID>
     folder-id: <YOUR_FOLDER_ID>
   ```
   On how to obtain OAuth token, refer to https://cloud.yandex.com/en/docs/iam/concepts/authorization/oauth-token
4. Activate new profile

   ```bash
   yc config profile activate vpn
   ```

### Run

```bash
# Source some environment variables for Yandex Cloud provider
. ./source-me # or YC_PROFILE=vpn . ./source-me

# Create infrastructure with Terraform
terraform init
terraform apply
# Type "yes" when propted

# Wait for a minute for the server to properly initiate

# Install OpenVPN with Ansible
ansible-playbook -i inventory site.yml
```

### Result

As a result, the `<IP_ADDRESS>.ovpn` file will be created in the current directory. Use it with any OpenVPN client (like official OpenVPN Client or Tunnelblick) to connect to your freshly created OpenVPN server.

## Uninstall

To delete everything simply run:
```bash
terraform destroy
# Type "yes" when propted
```

## Some technical details

The process will create `preemptible` Compute instance within the Instance Group. Preemptible means that instance can be restarted at any point and it also will be always restarting every 22-24h. In exchange, these instances is much cheaper than normal ones. If you want more stable solution, you can change `preemptible = true` to `preemptible = false` at [main.tf](./main.tf) file. Also, you can change the instance resources in the same file. By default, the smallest possible instance is created (2 cores, 2GB RAM, and only 20% guarateed CPU time).
