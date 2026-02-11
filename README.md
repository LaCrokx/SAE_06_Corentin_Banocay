# SAE6 DEVCLOUD - Infrastructure CI/CD Automatisée

Projet d'infrastructure complète avec Terraform, Ansible, GitLab et Kubernetes pour le déploiement automatisé d'un microservice Python.

## 📋 Vue d'Ensemble

Ce projet met en place une infrastructure CI/CD complète comprenant :

- **4 VMs provisionnées avec Terraform** : 1 GitLab + 3 Kubernetes
- **Ansible pour l'automatisation** : 4 playbooks pour configuration complète
- **GitLab CE** : Gestion du code et CI/CD
- **Kubernetes** : Orchestration avec 1 master + 2 workers
- **DNS interne** : Résolution de noms entre VMs
- **Application Python Tornado** : Microservice déployé automatiquement

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│           Proxmox Hypervisor (10.129.4.0/24)        │
└─────────────────────────────────────────────────────┘
                         │
       ┌─────────────────┼─────────────────┐
       │                 │                 │
       ▼                 ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  GitLab VM   │  │  K8s Master  │  │ K8s Worker 1 │
│  .187        │  │  .158        │  │  .250        │
│              │  │              │  │              │
│ - GitLab CE  │  │ - Control    │  │ - kubelet    │
│ - Runner     │  │   Plane      │  │ - apps       │
│ - DNS Server │  │ - CNI        │  │              │
└──────────────┘  └──────────────┘  └──────────────┘
                         │
                         ▼
                  ┌──────────────┐
                  │ K8s Worker 2 │
                  │  .159        │
                  │              │
                  │ - kubelet    │
                  │ - apps       │
                  └──────────────┘
```

## 📁 Structure du Projet

```
SAE6.DEVCLOUD.01/
├── terraform/                          # Provisionnement VMs
│   ├── main.tf                         # Définition des 4 VMs
│   ├── variables.tf                    # Variables Proxmox
│   ├── outputs.tf                      # IPs des VMs
│   ├── provider.tf                     # Provider Proxmox
│   └── generate_inventory.sh           # Génération inventaire dynamique
│
├── ansible/                            # Configuration & Déploiement
│   ├── inventory/
│   │   └── hosts.ini                   # Inventaire Ansible
│   ├── playbook_docker_kubernetes.yml  # Installation Docker + K8s
│   ├── playbook_dns.yml                # Configuration DNS
│   ├── playbook_gitlab.yml             # GitLab + Runner
│   └── playbook_deploy.yml             # Déploiement de l'app
│
├── scripts/
│   └── deploy_all.sh                   # Script de déploiement complet
│
└── tutorial-python-microservice-tornado-master (gitlab)/
    ├── .gitlab-ci.yml                  # Pipeline CI/CD
    ├── Dockerfile                      # Image Docker
    └── run.py                          # Application Python
```

## 🚀 Déploiement Rapide

### Prérequis

- Proxmox installé et accessible
- Terraform installé sur votre machine
- Ansible installé sur votre machine
- Template cloud-init Ubuntu/Debian dans Proxmox
- Clés SSH configurées

### 1. Configuration Terraform

Éditez `terraform/terraform.tfvars` :

```hcl
pm_api_url  = "https://YOUR_PROXMOX_IP:8006/api2/json"
pm_user     = "root@pam"
pm_password = "YOUR_PASSWORD"
target_node = "YOUR_NODE_NAME"
template_name = "YOUR_TEMPLATE_NAME"
vm_password = "YOUR_VM_PASSWORD"
```

### 2. Déploiement Complet (Automatique)

```bash
cd scripts
./deploy_all.sh
```

Ce script va :
1. ✅ Provisionner les 4 VMs avec Terraform
2. ✅ Installer Docker et Kubernetes
3. ✅ Configurer le DNS
4. ✅ Installer GitLab et Runner
5. ✅ Déployer l'application Python

### 3. Déploiement Manuel (Étape par Étape)

#### Étape 1 : Provisionner les VMs

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

#### Étape 2 : Vérifier la connectivité

```bash
cd ../ansible
ansible all -i inventory/hosts.ini -m ping
```

#### Étape 3 : Installer Docker et Kubernetes

```bash
ansible-playbook -i inventory/hosts.ini playbook_docker_kubernetes.yml
```

#### Étape 4 : Configurer le DNS

```bash
ansible-playbook -i inventory/hosts.ini playbook_dns.yml
```

#### Étape 5 : Installer GitLab

```bash
ansible-playbook -i inventory/hosts.ini playbook_gitlab.yml
```

#### Étape 6 : Déployer l'application

```bash
ansible-playbook -i inventory/hosts.ini playbook_deploy.yml
```

## 🔍 Vérification du Déploiement

### 1. Vérifier les VMs

```bash
cd terraform
terraform output
```

### 2. Vérifier Kubernetes

```bash
ssh root@10.129.4.158 "kubectl get nodes"
# Devrait afficher 3 nodes en Ready

ssh root@10.129.4.158 "kubectl get pods --all-namespaces"
# Devrait afficher tous les pods système
```

### 3. Vérifier GitLab

```bash
# Récupérer les credentials
ssh root@10.129.4.187 "cat /root/gitlab_credentials.txt"

# Accéder à GitLab
open http://10.129.4.187
# ou http://gitlab.local (si DNS configuré)
```

### 4. Vérifier le DNS

```bash
ssh root@10.129.4.158 "nslookup gitlab.local"
ssh root@10.129.4.187 "nslookup k8s-master.local"
```

### 5. Vérifier GitLab Runner

```bash
ssh root@10.129.4.187 "gitlab-runner list"
```

Pour enregistrer le runner :

```bash
# 1. Récupérer le token dans GitLab UI : Settings > CI/CD > Runners
# 2. SSH sur la VM GitLab
ssh root@10.129.4.187

# 3. Éditer le script
nano /tmp/register_runner.sh
# Remplacer le token par celui de GitLab

# 4. Exécuter
/tmp/register_runner.sh
```

## 📚 Playbooks Ansible Détaillés

### 1. playbook_docker_kubernetes.yml

**4 Plays**:
- Installation Docker sur GitLab VM
- Préparation nodes Kubernetes (swap, modules kernel, containerd)
- Initialisation cluster K8s sur master + Flannel CNI
- Jonction des workers au cluster

**Usage** :
```bash
ansible-playbook -i inventory/hosts.ini playbook_docker_kubernetes.yml
```

### 2. playbook_dns.yml

**2 Plays**:
- Installation dnsmasq sur GitLab VM avec records DNS
- Configuration clients DNS sur toutes les VMs

**Records DNS créés** :
- `gitlab.local` → 10.129.4.187
- `k8s-master.local` → 10.129.4.158
- `k8s-node-1.local` → 10.129.5.250
- `k8s-node-2.local` → 10.129.4.159

**Usage** :
```bash
ansible-playbook -i inventory/hosts.ini playbook_dns.yml
```

### 3. playbook_gitlab.yml

**Fonctionnalités** :
- Déploiement GitLab CE via Docker
- Configuration Container Registry (port 5005)
- Extraction automatique du mot de passe root
- Installation GitLab Runner
- Script de registration pré-configuré

**Usage** :
```bash
ansible-playbook -i inventory/hosts.ini playbook_gitlab.yml
```

### 4. playbook_deploy.yml

**Automatisation complète** :
- Authentification API GitLab
- Création du projet
- Copie du code Python
- Push vers GitLab
- Déclenchement pipeline CI/CD

**Usage** :
```bash
ansible-playbook -i inventory/hosts.ini playbook_deploy.yml
```

## 🔧 Dépannage

### Les VMs ne sont pas accessibles via SSH

```bash
# Vérifier les IPs
cd terraform
terraform output

# Mettre à jour l'inventaire
nano ansible/inventory/hosts.ini
```

### GitLab ne démarre pas

```bash
# Vérifier les logs
ssh root@10.129.4.187 "docker logs gitlab"

# Redémarrer GitLab
ssh root@10.129.4.187 "docker restart gitlab"

# GitLab peut prendre 5-10 minutes pour démarrer
```

### Le cluster Kubernetes ne s'initialise pas

```bash
# Vérifier les logs
ssh root@10.129.4.158 "journalctl -u kubelet -n 50"

# Réinitialiser si nécessaire
ssh root@10.129.4.158 "kubeadm reset"
# Puis relancer le playbook
```

### DNS ne fonctionne pas

```bash
# Vérifier dnsmasq
ssh root@10.129.4.187 "systemctl status dnsmasq"

# Tester directement
ssh root@10.129.4.187 "nslookup gitlab.local 127.0.0.1"

# Vérifier resolv.conf sur les clients
ansible all -i inventory/hosts.ini -m shell -a "cat /etc/resolv.conf"
```

### Pipeline GitLab ne se lance pas

1. Vérifier que le runner est enregistré : GitLab UI > Settings > CI/CD > Runners
2. Vérifier que `.gitlab-ci.yml` existe dans le repo
3. Vérifier les logs du runner :
   ```bash
   ssh root@10.129.4.187 "journalctl -u gitlab-runner -f"
   ```

## 📝 Fichiers de Configuration Importants

### terraform/terraform.tfvars (à créer)

```hcl
pm_api_url    = "https://192.168.1.10:8006/api2/json"
pm_user       = "root@pam"
pm_password   = "your-password"
target_node   = "pve"
template_name = "ubuntu-cloud-template"
vm_password   = "vm-password"
```

### ansible/inventory/hosts.ini

```ini
[gitlab]
gitlab-server ansible_host=10.129.4.187 ansible_user=root

[k8s_master]
k8s-master ansible_host=10.129.4.158 ansible_user=root

[k8s_workers]
k8s-node-1 ansible_host=10.129.5.250 ansible_user=root
k8s-node-2 ansible_host=10.129.4.159 ansible_user=root

[kubernetes:children]
k8s_master
k8s_workers

[dns_server]
gitlab-server ansible_host=10.129.4.187 ansible_user=root

[all:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

## 🎯 Résultats Attendus

Après un déploiement réussi :

✅ **4 VMs créées et configurées**
✅ **Cluster Kubernetes opérationnel** (1 master + 2 workers)
✅ **GitLab accessible** via http://gitlab.local ou http://10.129.4.187
✅ **GitLab Runner enregistré** et prêt pour CI/CD
✅ **DNS fonctionnel** entre toutes les VMs
✅ **Application Python** déployée dans GitLab
✅ **Pipeline CI/CD** configuré et exécutable

## 📞 Support

Pour toute question ou problème :
- Consultez les logs des playbooks Ansible
- Vérifiez l'état des services avec `systemctl status`
- Consultez les logs Docker avec `docker logs <container>`
- Vérifiez les logs Kubernetes avec `kubectl logs`

## 📄 Licence

Ce projet est réalisé dans le cadre de la SAÉ 6 - DevCloud.
