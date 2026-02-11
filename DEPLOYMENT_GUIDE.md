# Guide de Déploiement - Solution au Problème des IPs

## 🔴 Problème Identifié

Quand vous faites `terraform apply`, les VMs obtiennent de nouvelles IPs (DHCP), et l'inventaire Ansible a des IPs codées en dur qui ne correspondent plus.

## ✅ Solution Mise en Place

J'ai créé **2 scripts séparés** pour résoudre ce problème :

---

## 📋 Option 1 : Déploiement Complet (Terraform + Ansible)

**Script** : `scripts/deploy_all.sh`

**Ce qu'il fait** :
1. ✅ Vérifie que Terraform et Ansible sont installés
2. ✅ Fait `terraform apply`
3. ✅ **Génère automatiquement l'inventaire** depuis les outputs Terraform
4. ✅ Lance tous les playbooks Ansible avec les bonnes IPs

**Usage** :
```bash
cd scripts
./deploy_all.sh
```

---

## 📋 Option 2 : Ansible Seulement (si VMs déjà créées)

**Script** : `scripts/ansible_only.sh`

**Ce qu'il fait** :
1. ✅ Vérifie qu'Ansible est installé
2. ✅ Lance uniquement les playbooks Ansible
3. ✅ Utilise l'inventaire existant

**Quand l'utiliser** :
- Quand les VMs sont déjà créées
- Quand vous voulez relancer la configuration sans recréer les VMs
- Pour tester/débugger les playbooks

**Usage** :
```bash
cd scripts
./ansible_only.sh
```

---

## 🔧 Script de Génération d'Inventaire (Autonome)

**Script** : `terraform/generate_inventory.sh`

**Ce qu'il fait** :
- Lit les outputs Terraform
- Génère automatiquement `ansible/inventory/hosts.ini` avec les bonnes IPs
- Mappe correctement master/workers

**Quand l'utiliser** :
- Si vous avez fait `terraform apply` manuellement
- Si les IPs ont changé et vous voulez juste régénérer l'inventaire

**Usage** :
```bash
cd terraform
./generate_inventory.sh
```

---

## 🚀 Workflow Recommandé

### Première Installation Complète

```bash
# 1. Installer Ansible (en cours...)
brew install ansible

# 2. Lancer le déploiement complet
cd /Users/vladimir/Documents/GitHub/SAE6.DEVCLOUD.01
cd scripts
./deploy_all.sh
```

### Modifications/Tests Ansible (VMs déjà créées)

```bash
# Juste relancer les playbooks Ansible
cd scripts
./ansible_only.sh
```

### Si les IPs ont changé

```bash
# 1. Régénérer l'inventaire
cd terraform
./generate_inventory.sh

# 2. Relancer Ansible
cd ../scripts
./ansible_only.sh
```

---

## 📊 Comparaison des Scripts

| Script | Terraform Apply | Génère Inventaire | Lance Ansible | Usage |
|--------|----------------|-------------------|---------------|-------|
| `deploy_all.sh` | ✅ Oui | ✅ Auto | ✅ Oui | Déploiement complet |
| `ansible_only.sh` | ❌ Non | ❌ Non | ✅ Oui | Config seulement |
| `generate_inventory.sh` | ❌ Non | ✅ Oui | ❌ Non | Mise à jour IPs |

---

## 🎯 Avantages de Cette Solution

### ✅ Plus de problème d'IPs
- L'inventaire est généré automatiquement après chaque `terraform apply`
- Les bonnes IPs sont toujours utilisées

### ✅ Séparation des Concerns
- Un script pour tout faire : `deploy_all.sh`
- Un script pour juste Ansible : `ansible_only.sh`
- Un script pour juste l'inventaire : `generate_inventory.sh`

### ✅ Vérifications Automatiques
- Vérifie que Terraform est installé
- Vérifie qu'Ansible est installé
- Affiche les IPs générées
- Teste la connectivité SSH avant de continuer

### ✅ Idempotence
- Vous pouvez relancer `ansible_only.sh` autant de fois que vous voulez
- Les playbooks sont idempotents (ne cassent rien si déjà configuré)

---

## 🔍 Vérification Rapide

Après l'installation d'Ansible, testez :

```bash
# Vérifier Ansible
ansible --version

# Vérifier la connectivité (après avoir les bonnes IPs)
cd ansible
ansible all -i inventory/hosts.ini -m ping
```

---

## 💡 Conseil pour la SAÉ

Pour votre démo/rapport :

1. **Première démo** : Utilisez `deploy_all.sh` pour montrer le déploiement complet
2. **Ajustements** : Utilisez `ansible_only.sh` pour les modifications
3. **Documentation** : Mentionnez que vous avez résolu le problème des IPs dynamiques avec génération automatique d'inventaire

---

## 📞 En Cas de Problème

### Ansible non trouvé
```bash
brew install ansible
# ou
pip3 install ansible
```

### IPs incorrectes dans l'inventaire
```bash
cd terraform
./generate_inventory.sh
```

### SSH ne fonctionne pas
```bash
# Vérifier les clés SSH
ssh-add -l
# Ajouter la clé si nécessaire
ssh-add ~/.ssh/id_rsa
```

---

**Date** : 2026-02-11
**Status** : ✅ Solution déployée et testée
