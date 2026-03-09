# MERN Todo DevOps

Production-ready MERN stack application with complete DevOps automation pipeline, demonstrating Infrastructure as Code, containerization, and CI/CD best practices.

## 🔗 Live Demo

**Try the app:** [https://todo.tran-thien.id.vn](https://todo.tran-thien.id.vn/)

Deployed on DigitalOcean with automated SSL/TLS, showcasing the complete DevOps workflow from infrastructure provisioning to production deployment.

## 🎯 DevOps Highlights

**Infrastructure as Code (IaC)**
- Terraform for cloud infrastructure provisioning on DigitalOcean
- Ansible playbooks for automated server configuration
- Dockerized IaC tools for reproducible environments

**Containerization & Orchestration**
- Multi-stage Docker builds with optimized images
- Docker Compose for service orchestration
- Container networking and volume management
- Reverse proxy with automated SSL/TLS (Let's Encrypt)

**CI/CD Pipelines**
- Dual pipeline implementation: GitHub Actions + Jenkins
- Automated testing, building, and deployment
- Webhook-triggered builds with secret validation
- Zero-downtime deployments

**Monitoring & Observability**
- Prometheus for metrics collection
- Grafana dashboards for visualization
- Node Exporter & Blackbox Exporter
- Alertmanager for incident management

## 🏗️ Tech Stack

**Application**
- Frontend: React.js + Tailwind CSS
- Backend: Node.js + Express
- Database: MongoDB

**DevOps Tools**
- **IaC**: Terraform + Ansible
- **Containerization**: Docker + Docker Compose
- **CI/CD**: GitHub Actions + Jenkins
- **Monitoring**: Prometheus + Grafana
- **Reverse Proxy**: Nginx Proxy Manager
- **Cloud**: DigitalOcean

## 📁 Project Structure

```
├── app/
│   ├── backend/              # Node.js API + Dockerfile
│   └── frontend/             # React SPA + Dockerfile
├── infrastructure/
│   ├── terraform/            # IaC for cloud provisioning
│   └── ansible/              # Configuration management
├── jenkins/
│   └── Jenkinsfile           # Declarative pipeline
├── prometheus/               # Monitoring configs
├── alertmanager/             # Alert configs
└── docker-compose.yml        # Service definitions
```

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose
- DigitalOcean account with API token
- GitHub account

### 1. Infrastructure Provisioning with Terraform

**Generate SSH key:**
```bash
ssh-keygen -t rsa -b 4096 -f infrastructure/ansible/server_ssh_key -N ""
```

**Create `infrastructure/terraform/digital.auto.tfvars`:**
```hcl
do_token = "your_digitalocean_api_token"
ssh_key = "ssh_key_fingerprint_from_digitalocean"
```

**Deploy infrastructure using Dockerized Terraform:**
```bash
# Create IaC container
docker run -d -it --name todo-iac -v "$(pwd)/infrastructure":/root ubuntu:24.04

# Install Terraform
docker exec -it todo-iac bash
apt update && apt install -y unzip wget
cd /root/terraform
wget https://releases.hashicorp.com/terraform/1.14.6/terraform_1.14.6_linux_amd64.zip
unzip terraform_1.14.6_linux_amd64.zip && mv terraform /usr/local/bin/

# Provision infrastructure
terraform init
terraform apply
```

### 2. Configuration Management with Ansible

**Update `infrastructure/ansible/hosts.ini` with your server IP:**
```ini
[hosts_list]
YOUR_SERVER_IP ansible_user=root ansible_ssh_private_key_file=/root/ansible/server_ssh_key
```

**Configure environment variables in `infrastructure/ansible/todo-playbook.yml`:**
```yaml
MONGO_URI=mongodb://todo-mongo:27017/todo
GMAIL_USERNAME=your-email@gmail.com
GMAIL_PASSWORD=your-gmail-app-password
```

**Deploy with Ansible:**
```bash
# In IaC container
cd /root/ansible
apt install -y ansible
chmod 600 server_ssh_key
ansible-playbook -i hosts.ini todo-playbook.yml
```

**Ansible automatically:**
- Installs Docker & Docker Compose
- Creates Docker networks
- Deploys MongoDB, Frontend, Backend containers
- Sets up Nginx Proxy Manager for SSL/TLS
- Deploys Jenkins for CI/CD
- Configures Prometheus + Grafana monitoring

### 3. CI/CD: GitHub Actions

**Add GitHub Secrets:**
- `SERVER_HOST`: Your server IP
- `SERVER_USER`: `root`
- `SERVER_SSH_KEY`: Private key content from `infrastructure/ansible/server_ssh_key`

**Add Deploy Key:**
- Add public key content from `infrastructure/ansible/server_ssh_key.pub` to GitHub repo → Settings → Deploy keys

**Workflow triggers on:**
- Push to `main` branch
- Automatically rebuilds and redeploys containers

### 4. CI/CD: Jenkins Pipeline

**Access Jenkins:** `http://YOUR_SERVER_IP:8080`

**Setup:**
1. Get initial password: `docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword`
2. Install suggested plugins + SSH Agent plugin
3. Add credentials:
   - SSH key: `server_ssh_key` (Kind: SSH Username with private key)
   - Server IP: `server_host` (Kind: Secret text)
4. Create pipeline pointing to `jenkins/Jenkinsfile`

**Configure GitHub Webhook:**
1. Generate webhook secret: `openssl rand -hex 20`
2. In Jenkins, add credential:
   - Kind: Secret text, ID: `github-webhook-secret`
3. Jenkins → Manage Jenkins → System → GitHub section:
   - Add GitHub Server
   - Override Hook URL: `http://YOUR_SERVER_IP:8080/github-webhook/`
   - Shared secret: `github-webhook-secret`
4. Pipeline → Configure → Build Triggers:
   - Enable "GitHub hook trigger for GITScm polling"
5. GitHub repo → Settings → Webhooks → Add webhook:
   - Payload URL: `http://YOUR_SERVER_IP:8080/github-webhook/`
   - Secret: Paste your generated secret
   - Event: Just the push event

**Pipeline stages:**
- Connect to VPS via SSH
- Pull latest code
- Rebuild Docker containers
- Clean up unused images

### 5. SSL/TLS with Nginx Proxy Manager

**Access:** `http://YOUR_SERVER_IP:81`  
**Default login:** `admin@example.com` / `changeme`

**Configure Proxy Host:**
1. Dashboard → Proxy Hosts → Add Proxy Host
2. Details tab:
   - Domain: `todo.yourdomain.com`
   - Scheme: `http`, Forward to: `todo-frontend:80`
   - Enable: Cache Assets, Block Common Exploits, Websockets Support
3. Custom Locations tab → Add Location:
   - Location: `/api`
   - Scheme: `http`, Forward to: `todo-backend:8000`
4. SSL tab:
   - Request new SSL Certificate (Let's Encrypt)
   - Enable: Force SSL, HTTP/2 Support, HSTS
5. Save

**Your app is now live at:** `https://todo.yourdomain.com` 🚀

### 6. Monitoring

**Access Grafana:** Configure via Ansible deployment
- Prometheus scrapes metrics from Node Exporter
- Grafana visualizes system metrics
- Alertmanager sends notifications

## 🔄 CI/CD Pipeline Flow

```
Developer Push
    ↓
GitHub/Jenkins Webhook
    ↓
Build Pipeline Triggered
    ↓
├─ GitHub Actions (Automated)
│  └─ SSH to VPS → Pull Code → Rebuild Containers
│
└─ Jenkins (Alternative)
   └─ SSH to VPS → Pull Code → Rebuild Containers
    ↓
Zero-Downtime Deployment
```

## 🐳 Docker Architecture

```
Docker Network: todo-network
├─ todo-mongo          (MongoDB)
├─ todo-backend        (Node.js API)
├─ todo-frontend       (React SPA)
├─ nginx-proxy-manager (Reverse Proxy + SSL)
├─ jenkins             (CI/CD)
├─ prometheus          (Metrics)
├─ grafana             (Dashboards)
├─ node-exporter       (System metrics)
├─ blackbox-exporter   (HTTP probing)
└─ alertmanager        (Alerts)
```

## 🔑 Key DevOps Practices

✅ **Infrastructure as Code**: Reproducible environments via Terraform  
✅ **Configuration Management**: Idempotent deployments with Ansible  
✅ **Containerization**: All services run in isolated Docker containers  
✅ **Multi-stage Builds**: Optimized Docker images with build caching  
✅ **Secret Management**: SSH keys, API tokens managed securely  
✅ **Automated CI/CD**: Dual pipelines (GitHub Actions + Jenkins)  
✅ **Monitoring**: Prometheus metrics + Grafana dashboards  
✅ **SSL/TLS**: Automated certificate management with Let's Encrypt  
✅ **Reverse Proxy**: Centralized routing via Nginx Proxy Manager  
✅ **Zero-Downtime Deployment**: Rolling updates with Docker Compose  

## 📊 Monitoring Stack

- **Prometheus**: Time-series metrics database
- **Grafana**: Visualization and dashboards
- **Node Exporter**: System-level metrics (CPU, memory, disk)
- **Blackbox Exporter**: HTTP/HTTPS endpoint monitoring
- **Alertmanager**: Alert routing and notification

## 🔒 Security Features

- SSH key-based authentication (no passwords)
- Automated SSL/TLS certificates via Let's Encrypt
- Docker network isolation
- Environment variables for sensitive data
- GitHub webhook secret validation
- Non-root user execution in containers (best practice)

## 📝 Skills Demonstrated

**Infrastructure**
- Cloud infrastructure provisioning (DigitalOcean)
- Terraform state management
- Ansible inventory and playbook development
- SSH key management across pipeline

**Containerization**
- Dockerfile optimization (multi-stage builds)
- Docker Compose orchestration
- Container networking
- Volume management
- Image optimization and layering

**CI/CD**
- GitHub Actions workflows
- Jenkins declarative pipelines
- Webhook integration
- Automated testing and deployment
- Secret management in CI/CD

**Monitoring & Operations**
- Prometheus metric collection
- Grafana dashboard creation
- Log aggregation
- Alert configuration
- System health monitoring

---

**Built for DevOps portfolio and interview demonstrations** 🚀
