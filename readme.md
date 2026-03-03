# MERN Todo DevOps

A full-stack MERN (MongoDB, Express, React, Node.js) todo application with complete DevOps infrastructure automation using Terraform, Ansible, and Docker.

## 📋 Table of Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Deployment Guide](#deployment-guide)
  - [1. Infrastructure Provisioning](#1-infrastructure-provisioning)
  - [2. GitHub Actions Setup](#2-github-actions-setup)
  - [3. Application Deployment](#3-application-deployment)
- [Local Development](#local-development)
- [Features](#features)

## 🏗️ Architecture

- **Frontend**: React.js with Tailwind CSS
- **Backend**: Node.js with Express
- **Database**: MongoDB
- **Infrastructure**: DigitalOcean Droplets
- **IaC**: Terraform
- **Configuration Management**: Ansible
- **Containerization**: Docker & Docker Compose
- **CI/CD**: GitHub Actions, Jenkins
- **Monitoring**: Grafana, Prometheus

## ✅ Prerequisites

Before you begin, ensure you have the following:

- [Docker](https://docs.docker.com/get-docker/) & [Docker Compose](https://docs.docker.com/compose/install/)
- DigitalOcean account with API token
- GitHub account

**Note:** Terraform and Ansible will run inside Docker containers, so you don't need to install them locally.

## 📁 Project Structure

```
├── app/
│   ├── backend/          # Node.js/Express API
│   └── frontend/         # React application
├── infrastructure/
│   ├── terraform/        # Infrastructure as Code
│   └── ansible/          # Configuration management
└── docker-compose.yml    # Container orchestration
```

## 🚀 Deployment Guide

### 0. Setup Configuration Files

Before provisioning infrastructure, you need to create sensitive configuration files that are excluded from version control.

#### Step 1: Generate SSH Key Pair

First, generate the SSH key pair that will be used throughout the deployment pipeline:

```bash
ssh-keygen -t rsa -b 4096 -f infrastructure/ansible/server_ssh_key -N ""
```

This creates two files:
- `infrastructure/ansible/server_ssh_key` - **Private key** (keep this secret!)
- `infrastructure/ansible/server_ssh_key.pub` - **Public key** (share this)

The `server_ssh_key` is your **main infrastructure SSH key** that:
- **Terraform uses** to provision and configure DigitalOcean droplets
- **Ansible uses** to deploy applications to the servers
- **GitHub Actions uses** for automated deployments

⚠️ **Critical:** This key is used throughout the entire deployment pipeline. Keep it secure and never commit it to version control.

#### Step 2: Get SSH Key Fingerprint from DigitalOcean

Upload your public key to DigitalOcean and obtain its fingerprint:

1. Display your public key:
   ```bash
   cat infrastructure/ansible/server_ssh_key.pub
   ```

2. Copy the entire output

3. Log in to DigitalOcean and go to **Settings** → **Security** → **SSH Keys**

4. Click **Add SSH Key**

5. Paste the public key and give it a name (e.g., "Terraform Server Key")

6. After saving, DigitalOcean will display the **fingerprint** in the format: `08:a9:ab:e0:6e:82:3a:98:74:0e:f4:3b:52:db:7f:98`

7. **Copy this fingerprint** - you'll need it in the next step

#### Step 3: Get DigitalOcean API Token

1. In DigitalOcean, go to **API** → **Tokens/Keys**
2. Click **Generate New Token**
3. Give it a name and select **read & write** access
4. Copy the token (starts with `dop_v1_`)
5. ⚠️ **Save it immediately** - you won't be able to see it again!

#### Step 4: Create Terraform Variables File

Now create `infrastructure/terraform/digital.auto.tfvars` with the values you obtained:

```hcl
do_token = "your_digitalocean_api_token"
ssh_key = "your_ssh_key_fingerprint"
```

**Example with real values:**
```hcl
do_token = "dop_v1_f95853cabb09f901389aaeb2e04491d85f6e0b1389ddebd92e59037430671aca"
ssh_key = "08:a9:ab:e0:6e:82:3a:98:74:0e:f4:3b:52:db:7f:98"
```

**Key Relationship Flow:**
```
1. Generate SSH Key Pair
   └─ server_ssh_key (private)
   └─ server_ssh_key.pub (public)
         ↓
2. Upload public key to DigitalOcean
         ↓
3. DigitalOcean generates fingerprint
         ↓
4. Copy fingerprint to digital.auto.tfvars
         ↓
5. Terraform uses fingerprint to reference the key
         ↓
6. Terraform uses server_ssh_key for SSH access
```

### 1. Infrastructure Provisioning

#### Step 1: Set Up Docker Network and MongoDB

First, create a Docker network and start MongoDB:

```bash
docker network create todo-network
docker run -d --name todo-mongo --network todo-network -v mongo-data:/data/db --restart always mongo:7
```

#### Step 2: Create Infrastructure Container

Create a container with Terraform installed:

```bash
docker run -d -it --name todo-iac -v D:\.workspace\mern-todo-devops\infrastructure\:/root ubuntu:24.04
```

**Note:** Replace `D:\.workspace\mern-todo-devops` with your actual project path.

#### Step 3: Install Terraform in Container

Access the container and install Terraform:

```bash
docker exec -it todo-iac bash
```

Inside the container, run:

```bash
apt update
apt install unzip wget -y
cd /root/terraform
wget https://releases.hashicorp.com/terraform/1.14.6/terraform_1.14.6_linux_amd64.zip
unzip terraform_1.14.6_linux_amd64.zip
mv terraform /usr/local/bin/
```

#### Step 4: Provision Infrastructure

Now provision your DigitalOcean infrastructure:

```bash
terraform init
terraform apply
```

Terraform will use the `server_ssh_key` (whose fingerprint is in `digital.auto.tfvars`) to create and access your droplets.

After successful provisioning, note down the **droplet IP addresses** from the Terraform output.

Type `exit` to leave the container when done.

### 2. GitHub Actions Setup

Configure deploy keys for secure CI/CD deployment:

#### Step 1: Connect to Your VPS

```bash
ssh -i infrastructure/ansible/server_ssh_key root@YOUR_DROPLET_IP
```

Replace `YOUR_DROPLET_IP` with the actual IP address from Terraform output.

#### Step 2: Generate SSH Deploy Key

Run the following command on your VPS to generate a deployment key:

```bash
ssh-keygen -t ed25519 -f /root/.ssh/github_deploy -N ""
```

This creates two files:
- `/root/.ssh/github_deploy` (private key)
- `/root/.ssh/github_deploy.pub` (public key)

#### Step 3: Add Public Key to GitHub

Display the public key:

```bash
cat /root/.ssh/github_deploy.pub
```

Copy the output and add it to your GitHub repository:

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Deploy keys**
3. Click **Add deploy key**
4. Paste the public key
5. Give it a descriptive title (e.g., "Todo Server Deploy Key")
6. Check **Allow write access** if needed
7. Click **Add key**

#### Step 4: Add GitHub Secrets for CI/CD

Your GitHub Actions workflow needs access to your servers. Add the following secrets:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret** for each of the following:

**Required Secrets:**

- **`SERVER_HOST`**: Your droplet IP address (from Terraform output)
- **`SERVER_USER`**: `root` (or your configured SSH user)
- **`SERVER_SSH_KEY`**: The SSH private key that Terraform uses
  ```bash
  cat infrastructure/ansible/server_ssh_key
  ```
  Copy the entire output (including `-----BEGIN` and `-----END` lines) and paste as the secret value.
  
  ⚠️ **Critical:** This is the **same private key** that:
  - Terraform uses to create the VPS (its fingerprint is in `digital.auto.tfvars`)
  - Ansible uses to configure the servers
  - Should match the public key uploaded to DigitalOcean

- **`DEPLOY_PRIVATE_KEY`**: The deploy key generated on the VPS (from Step 2)
  ```bash
  cat /root/.ssh/github_deploy
  ```

**Understanding the Two Keys:**
- `SERVER_SSH_KEY`: Infrastructure key for server access (used by Terraform/Ansible/CI)
- `DEPLOY_PRIVATE_KEY`: Application deployment key for GitHub repo access (generated on VPS)

### 3. Application Deployment

#### Configure Ansible Inventory

Before deploying, update the Ansible inventory file with your droplet IP address:

1. Open `infrastructure/ansible/hosts.ini`
2. Replace `SERVER_IP_ADDRESS` with the actual IP from your Terraform output:

```ini
[hosts_list]
YOUR_DROPLET_IP ansible_user=root ansible_ssh_private_key_file=/root/ansible/server_ssh_key
```

**Example:**
```ini
[hosts_list]
164.92.123.45 ansible_user=root ansible_ssh_private_key_file=/root/ansible/server_ssh_key
```

#### Deploy with Ansible

Access the `todo-iac` container and use Ansible to deploy:

```bash
docker exec -it todo-iac bash
```

Inside the container, install Ansible and run the playbook:

```bash
cd /root/ansible
apt install ansible -y
ansible hosts_list -i hosts.ini -m ping
ansible-playbook -i hosts.ini todo-playhook.yml
```

This will:
- Install Docker and Docker Compose on the remote server
- Configure the server environment
- Deploy the application containers
- Set up necessary networking and security

Type `exit` to leave the container when done.

#### Alternative: Local Development with Docker Compose

For local development without remote deployment:

```bash
docker compose up -d --build
```

## 💻 Local Development

To run the application locally:

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd mern-todo-devops
   ```

2. **Start with Docker Compose**
   ```bash
   docker-compose up --build
   ```

3. **Access the application**
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:5000

4. **Stop the application**
   ```bash
   docker-compose down
   ```

## ✨ Features

- ✅ User authentication (register, login, forgot password)
- ✅ Create, read, update, and delete tasks
- ✅ Mark tasks as complete/incomplete
- ✅ Filter tasks by status (all, active, completed)
- ✅ Automated task scheduling
- ✅ Responsive UI with Tailwind CSS
- ✅ Fully containerized architecture
- ✅ Infrastructure as Code
- ✅ Automated deployment pipeline

## 📝 Notes

- **Important:** Update `infrastructure/ansible/hosts.ini` with your actual droplet IP address after Terraform provisioning (see Section 3)
- All infrastructure tooling (Terraform, Ansible) runs inside the `todo-iac` Docker container for consistency
- Configure environment variables in your deployment environment
- Ensure firewall rules allow traffic on required ports (80, 443, 3000, 5000)
- MongoDB credentials should be stored as environment variables or secrets

### 🔒 Security Notes

The following sensitive files are excluded from version control (`.gitignore`):
- `infrastructure/terraform/digital.auto.tfvars` - Contains DigitalOcean API token and SSH key fingerprint
- `infrastructure/ansible/server_ssh_key` - SSH private key for server access
- `infrastructure/ansible/server_ssh_key.pub` - Corresponding public key

**Never commit these files to your repository!** Each team member/environment should create their own copies based on the instructions in the deployment guide.

---

**Built with ❤️ using the MERN stack and DevOps best practices**
