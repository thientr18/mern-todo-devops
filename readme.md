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
  - [4. Nginx Proxy Manager Setup](#4-nginx-proxy-manager-setup)
  - [5. Jenkins CI/CD Setup](#5-jenkins-cicd-setup)
- [Local Development](#local-development)
- [Features](#features)

## 🏗️ Architecture

- **Frontend**: React.js with Tailwind CSS
- **Backend**: Node.js with Express
- **Database**: MongoDB
- **Reverse Proxy**: Nginx Proxy Manager with SSL/TLS (Let's Encrypt)
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

**📍 Run on your local machine:**
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
- **Jenkins uses** for CI/CD pipeline deployments

⚠️ **Critical:** This key is used throughout the entire deployment pipeline (Terraform, Ansible, GitHub Actions, and Jenkins). Keep it secure and never commit it to version control.

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

#### Step 5: Prepare Email Credentials for Deployment

The backend requires environment variables for database connection, email service, and JWT authentication. **Ansible will automatically create the `.env` file on the server**, so you don't need to create it locally.

**What you need to prepare:**

- **Gmail Account**: For sending password reset emails
- **Gmail App Password**: Generate at https://myaccount.google.com/apppasswords
  - You need to enable 2-factor authentication first
  - Select "App passwords" and create a new one for "Mail"
  - Copy this password - you'll configure it in the Ansible playbook

**Environment Variables (configured in Ansible playbook):**

- **`MONGO_URI`**: MongoDB connection string (use `todo-mongo` as host for Docker network)
- **`GMAIL_USERNAME`**: Your Gmail address for sending password reset emails
- **`GMAIL_PASSWORD`**: Gmail App Password (NOT your regular Gmail password)
- **`PORT`**: Backend server port (default: 8000)
- **`JWT_SECRET`**: A secure random string for JWT token encryption
- **`SERVER_IP`**: Automatically detected by Ansible using `{{ ansible_default_ipv4.address }}`

⚠️ **Security Notes:**
- Never commit credentials to your repository
- Use different credentials for development and production
- You'll configure these values in the Ansible playbook before deployment

### 1. Infrastructure Provisioning

#### Step 1: Create Infrastructure Container

**📍 Run on your local machine:**
```bash
docker run -d -it --name todo-iac -v "$(pwd)/infrastructure":/root ubuntu:24.04
```

#### Step 2: Install Terraform in Container

**📍 Run on your local machine to access the container:**
```bash
docker exec -it todo-iac bash
```

**🐳 Inside IAC container, run:**
```bash
apt update
apt install unzip wget -y
cd /root/terraform
wget https://releases.hashicorp.com/terraform/1.14.6/terraform_1.14.6_linux_amd64.zip
unzip terraform_1.14.6_linux_amd64.zip
mv terraform /usr/local/bin/
```

#### Step 3: Provision Infrastructure

**🐳 Still inside IAC container:**
```bash
terraform init
terraform apply
```

Terraform will use the `server_ssh_key` (whose fingerprint is in `digital.auto.tfvars`) to create and access your droplets.

After successful provisioning, note down the **droplet IP addresses** from the Terraform output.

**Exit the container:**
```bash
exit
```

### 2. GitHub Actions Setup

Configure GitHub secrets and deploy keys for automated CI/CD deployment:

#### Step 1: Add Deploy Key to GitHub

To allow the VPS server to pull code from your private GitHub repository, add the public key as a deploy key:

**📍 Run on your local machine:**
```bash
cat infrastructure/ansible/server_ssh_key.pub
```

Copy the output and add it to your GitHub repository:

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Deploy keys**
3. Click **Add deploy key**
4. Paste the public key
5. Give it a descriptive title (e.g., "VPS Server Deploy Key")
6. Check **Allow write access** if your workflow requires pushing changes
7. Click **Add key**

**How it works:**
- Ansible will copy `server_ssh_key` to the VPS as `/root/.ssh/server_ssh_key`
- When VPS tries to pull from GitHub, it uses this key for authentication
- GitHub verifies the key matches the Deploy Key you added above
- This allows secure code deployment without storing passwords

#### Step 2: Add GitHub Secrets

Your GitHub Actions workflow needs access to your servers. Add the following secrets:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret** for each of the following:

**Required Secrets:**

- **`SERVER_HOST`**: Your droplet IP address (from Terraform output)
- **`SERVER_USER`**: `root` (or your configured SSH user)
- **`SERVER_SSH_KEY`**: The SSH private key that Terraform uses
  
  **📍 Run on your local machine:**
  ```bash
  cat infrastructure/ansible/server_ssh_key
  ```
  Copy the entire output (including `-----BEGIN` and `-----END` lines) and paste as the secret value.
  
  ⚠️ **Critical:** This is the **same private key** that:
  - Terraform uses to create the VPS (its fingerprint is in `digital.auto.tfvars`)
  - Ansible uses to configure the servers
  - GitHub Actions uses to deploy the application
  - Jenkins uses for CI/CD deployments
  - Should match the public key uploaded to DigitalOcean and GitHub Deploy Keys

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

#### Configure Email Credentials in Playbook

Before deploying, you need to configure the email credentials in the Ansible playbook. **Ansible will automatically create all `.env` files on the server** with the correct configuration.

1. Open `infrastructure/ansible/todo-playbook.yml`

2. Locate the "Create backend .env" task

3. Update the `GMAIL_USERNAME` and `GMAIL_PASSWORD` values with your Gmail credentials:

```yaml
- name: Create backend .env
  copy:
    dest: /root/mern-todo-app/app/backend/.env
    content: |
      MONGO_URI=mongodb://todo-mongo:27017/todo
      GMAIL_USERNAME=
      GMAIL_PASSWORD=
      SERVER_DOMAIN=
      JWT_SECRET=<0513gVeUv'£
      PORT=8000
    mode: "0600"
```

**Important:**
- Replace the empty `GMAIL_USERNAME=` with your actual Gmail address
- Replace the empty `GMAIL_PASSWORD=` with your Gmail App Password (from Step 5)
- Replace the empty `SERVER_DOMAIN=` with your domain (e.g., `todo.yourdomain`)
- You can use different credentials for production vs development
- The `.env` file will be created automatically during Ansible deployment

**Example configuration:**
```yaml
- name: Create backend .env
  copy:
    dest: /root/mern-todo-app/app/backend/.env
    content: |
      MONGO_URI=mongodb://todo-mongo:27017/todo
      GMAIL_USERNAME=production.app@gmail.com
      GMAIL_PASSWORD=wxyzabcdefghijkl
      SERVER_DOMAIN=todo.yourdomain
      JWT_SECRET=<0513gVeUv'£
      PORT=8000
    mode: "0600"
```

#### Deploy with Ansible

**📍 Run on your local machine to access IAC container:**
```bash
docker exec -it todo-iac bash
```

**🐳 Inside IAC container, install Ansible and deploy:**
```bash
cd /root/ansible
apt install ansible -y
chmod 600 /root/ansible/server_ssh_key
ansible hosts_list -i hosts.ini -m ping
ansible-playbook -i hosts.ini todo-playbook.yml
```

This will:
- Install Docker and Docker Compose on the remote server
- Create the Docker network (`todo-network`) on the remote server
- Deploy and run MongoDB container on the remote server
- Copy SSH key to server as `/root/.ssh/server_ssh_key` for GitHub access
- Configure SSH settings for GitHub authentication
- Pull code from your private GitHub repository
- Create backend `.env` file with your credentials
- Build and run application containers (frontend, backend, nginx-proxy-manager)
- Deploy Jenkins container for CI/CD pipeline
- Deploy monitoring tools (Prometheus, Grafana, Node Exporter, Blackbox Exporter, Alertmanager)
- Clean up unused Docker images

**Exit the container:**
```bash
exit
```

### 4. Nginx Proxy Manager Setup

Configure Nginx Proxy Manager as a reverse proxy with automatic HTTPS for your domain. Nginx Proxy Manager is already included in your Docker Compose configuration and provides a web-based interface for managing proxies and SSL certificates.

#### Step 1: Configure DNS

Before accessing Nginx Proxy Manager, configure your domain's DNS settings:

1. Go to your domain registrar's DNS management panel
2. Add an **A record** pointing to your droplet's IP address:
   - **Type**: A
   - **Name**: `todo` (or `@` for root domain)
   - **Value**: `YOUR_DROPLET_IP`
   - **TTL**: 3600 (or default)
3. Wait for DNS propagation (usually 5-15 minutes, can take up to 48 hours)
4. Verify DNS resolution: `ping todo.yourdomain.com`

#### Step 2: Access Nginx Proxy Manager Dashboard

Open your browser and navigate to:
```
http://YOUR_DROPLET_IP:81
```

**Default login credentials:**
- **Email**: `admin@example.com`
- **Password**: `changeme`

⚠️ **Important:** Change the default password immediately after first login!

#### Step 3: Create Proxy Host for Frontend

1. Navigate to **Dashboard** → **Proxy Hosts** → **Add Proxy Host**

2. In the **Details** tab, configure:
   - **Domain Names**: `todo.yourdomain.com` (or your actual domain)
   - **Scheme**: `http`
   - **Forward Hostname / IP**: `todo-frontend`
   - **Forward Port**: `80`
   - **Cache Assets**: ✅
   - **Block Common Exploits**: ✅
   - **Websockets Support**: ✅

3. Click **Save** (don't configure SSL yet)

#### Step 4: Add Backend API Route

1. Go back to your newly created Proxy Host and click **Edit**

2. Navigate to the **Custom Locations** tab

3. Click **Add Location** and configure:
   - **Define Location**: `/api`
   - **Scheme**: `http`
   - **Forward Hostname / IP**: `todo-backend`
   - **Forward Port**: `8000`

4. Click **Save**

#### Step 5: Enable HTTPS with SSL

1. Edit your Proxy Host again

2. Navigate to the **SSL** tab

3. Configure SSL settings:
   - **SSL Certificate**: Select **Request a new SSL Certificate**
   - **Force SSL**: ✅
   - **HTTP/2 Support**: ✅
   - **HSTS Enabled**: ✅

4. Click **Save**

Nginx Proxy Manager will automatically:
- Request a free SSL certificate from Let's Encrypt
- Configure HTTPS for your domain
- Enable automatic HTTP to HTTPS redirect
- Handle certificate renewal automatically

**✅ Your application is now accessible at:** `https://todo.yourdomain.com`

**Benefits of Nginx Proxy Manager:**
- 🖥️ Web-based GUI for easy management
- 🔒 Automatic SSL certificate generation and renewal
- 🔄 No manual nginx configuration files needed
- 📊 Built-in access logs and statistics
- 🔧 Easy to add multiple domains and services

### 5. Jenkins CI/CD Setup

Jenkins is automatically deployed on your server via the Ansible playbook and provides an alternative CI/CD pipeline to GitHub Actions. Jenkins is particularly useful for complex build workflows, scheduled jobs, and environments where you need more control over the build process.

**Note:** Jenkins uses the **same SSH key** (`server_ssh_key`) that was created initially for Terraform, Ansible, and GitHub Actions.

#### Step 1: Access Jenkins Dashboard

Jenkins is automatically deployed via the Ansible playbook and runs on port 8080.

Open your browser and navigate to:
```
http://YOUR_DROPLET_IP:8080
```

#### Step 2: Get Initial Admin Password

To unlock Jenkins for the first time, you need to retrieve the initial admin password from the server:

**📍 Run on your local machine:**
```bash
ssh -i infrastructure/ansible/server_ssh_key root@YOUR_DROPLET_IP
```

**🖥️ On the VPS server, run:**
```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Copy the password and paste it into the Jenkins unlock page.

**Exit the VPS:**
```bash
exit
```

#### Step 3: Complete Jenkins Setup

1. After unlocking, click **Install suggested plugins**
2. Create your first admin user:
   - Username: Choose your username
   - Password: Choose a strong password
   - Full name: Your name
   - Email: Your email address
3. Click **Save and Continue**
4. Keep the default Jenkins URL and click **Save and Finish**
5. Click **Start using Jenkins**

#### Step 4: Install SSH Agent Plugin

The Jenkins pipeline requires the SSH Agent plugin to connect to your VPS:

1. Go to **Dashboard** → **Manage Jenkins** → **Manage Plugins**
2. Click the **Available plugins** tab
3. Search for "**SSH Agent**"
4. Check the box next to **SSH Agent Plugin**
5. Click **Install** (or **Install without restart**)
6. Wait for installation to complete

#### Step 5: Add SSH Key Credential to Jenkins

Now configure Jenkins to use the **same `server_ssh_key`** that you created initially:

1. Go to **Dashboard** → **Manage Jenkins** → **Manage Credentials**
2. Click on **(global)** domain
3. Click **Add Credentials** in the left sidebar
4. Configure the credential:
   - **Kind**: SSH Username with private key
   - **ID**: `server_ssh_key` (must match the Jenkinsfile)
   - **Description**: VPS Server SSH Key
   - **Username**: `root`
   - **Private Key**: Select **Enter directly**
   - Click **Add** button under the key text area

5. Get your SSH private key:
   
   **📍 Run on your local machine:**
   ```bash
   cat infrastructure/ansible/server_ssh_key
   ```
   
   Copy the entire output (including `-----BEGIN` and `-----END` lines)

6. Paste the private key into the **Key** text area in Jenkins

7. Click **Create**

**Key Reuse Confirmation:**
This is the **same `server_ssh_key`** used by:
- ✅ Terraform for infrastructure provisioning
- ✅ Ansible for configuration management
- ✅ GitHub Actions for automated deployment
- ✅ Jenkins for CI/CD pipeline (now configured)

#### Step 6: Add VPS IP as Secret

Store your server IP address as a Jenkins credential:

1. Still in **Manage Credentials**, click **Add Credentials** again
2. Configure the credential:
   - **Kind**: Secret text
   - **Scope**: Global
   - **Secret**: `YOUR_DROPLET_IP` (your actual server IP address)
   - **ID**: `server_host` (must match the Jenkinsfile)
   - **Description**: VPS Server IP Address
3. Click **Create**

#### Step 7: Create Jenkins Pipeline

1. Go back to **Dashboard**
2. Click **New Item**
3. Enter item name: `mern-todo-deploy` (or your preferred name)
4. Select **Pipeline** and click **OK**
5. In the pipeline configuration:
   - **Description**: "Deploy MERN Todo App to VPS"
   - Scroll down to **Pipeline** section
   - **Definition**: Select **Pipeline script from SCM**
   - **SCM**: Select **Git**
   - **Repository URL**: `https://github.com/thientr18/mern-todo-devops.git`
   - **Branch Specifier**: `*/main`
   - **Script Path**: `jenkins/Jenkinsfile` ⚠️ **Important: This tells Jenkins where to find the pipeline script**
6. Click **Save**

**What is Jenkinsfile?**
The `jenkins/Jenkinsfile` is a pipeline script that defines the CI/CD process. It:
- Clones the repository from GitHub
- Connects to your VPS using the `server_ssh_key` credential
- Uses the `server_host` IP address to SSH into the server
- Pulls the latest code on the VPS
- Rebuilds and restarts Docker containers
- Cleans up unused Docker images

#### Step 8: Run Your First Build

1. On the pipeline page, click **Build Now**
2. Watch the build progress in the **Build History**
3. Click on the build number (e.g., #1) to see details
4. Click **Console Output** to view real-time logs

**What the pipeline does:**
1. **Clone Repo**: Pulls the latest code from your GitHub repository
2. **Deploy to VPS**: 
   - Connects to VPS using SSH (`server_ssh_key` credential)
   - Pulls latest changes from GitHub
   - Rebuilds and restarts Docker containers
   - Cleans up unused Docker images

#### Pipeline Workflow

The Jenkins pipeline (`jenkins/Jenkinsfile`) performs the following steps:

```groovy
stage('Deploy to VPS')
  └─ Use SSH credentials (server_ssh_key)
  └─ Connect to VPS (using server_host IP)
  └─ Pull changes on VPS
  └─ Rebuild containers
  └─ Clean up Docker images
```

#### Trigger Options

You can configure automatic triggers for your Jenkins pipeline:

1. Edit your pipeline configuration
2. Under **Build Triggers**, you can enable:
   - **GitHub hook trigger for GITScm polling** - Build automatically when you push to GitHub
   - **Poll SCM** - Check for changes periodically (e.g., `H/5 * * * *` for every 5 minutes)
   - **Build periodically** - Build on a schedule (e.g., `H 2 * * *` for daily at 2 AM)

**To enable GitHub webhook:**
1. In your GitHub repository, go to **Settings** → **Webhooks**
2. Click **Add webhook**
3. Payload URL: `http://YOUR_DROPLET_IP:8080/github-webhook/`
4. Content type: `application/json`
5. Select **Just the push event**
6. Click **Add webhook**

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

### Command Execution Locations

**📍 Local Machine:** Your computer where the repository is cloned
- Generate SSH keys
- Create environment files
- Run Docker to create IAC container
- Connect to IAC container or VPS server

**🐳 IAC Container:** Docker container running Ubuntu with Terraform/Ansible
- Install and run Terraform
- Install and run Ansible
- Deploy infrastructure and applications

**🖥️ VPS Server:** DigitalOcean droplet (production server)
- Application runs here after deployment
- Access Nginx Proxy Manager dashboard for SSL and proxy configuration

### Important Notes

- **Update** `infrastructure/ansible/hosts.ini` with your actual droplet IP address after Terraform provisioning (see Section 3)
- **Email Configuration:** Configure Gmail credentials in `infrastructure/ansible/todo-playbook.yml` before deployment - Ansible will automatically create all `.env` files on the server
- All infrastructure tooling (Terraform, Ansible) runs inside the `todo-iac` Docker container for consistency
- Ansible automatically creates the Docker network and MongoDB container on your DigitalOcean droplet
- **SSH Key Reuse:** The same `server_ssh_key` is used across Terraform, Ansible, GitHub Actions, and Jenkins for consistency and security
- Ensure firewall rules allow traffic on required ports (80, 81, 443, 8080)
  - Port 80: HTTP traffic (redirects to HTTPS)
  - Port 81: Nginx Proxy Manager dashboard
  - Port 443: HTTPS traffic
  - Port 8080: Jenkins dashboard
- Change the default Nginx Proxy Manager password immediately after first login
- Change the Jenkins admin password after initial setup

### 🔒 Security Notes

The following sensitive files are excluded from version control (`.gitignore`):
- `infrastructure/terraform/digital.auto.tfvars` - Contains DigitalOcean API token and SSH key fingerprint
- `infrastructure/ansible/server_ssh_key` - SSH private key for server access
- `infrastructure/ansible/server_ssh_key.pub` - Corresponding public key

**Never commit these files to your repository!** Each team member/environment should create their own copies based on the instructions in the deployment guide.

**Note:** Backend environment variables (`.env` files) are automatically created by Ansible during deployment - you don't need to create them locally.

**Additional Security Recommendations:**
- Use different Gmail accounts/passwords for development and production
- Rotate JWT secrets periodically
- Use strong, randomly generated passwords
- Store production credentials in secure secret management systems
- Review and update the Ansible playbook's email credentials before each deployment

---

**Built with ❤️ using the MERN stack and DevOps best practices**
