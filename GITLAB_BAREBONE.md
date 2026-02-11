# Installation GitLab CE & Runner en Barebone

## 🎯 Changement Effectué

Le playbook `playbook_gitlab.yml` a été **complètement réécrit** pour installer GitLab CE et GitLab Runner en **mode barebone** (packages natifs) au lieu de Docker.

## 📋 Différences : Docker vs Barebone

| Aspect | Docker (Ancien) | Barebone (Nouveau) |
|--------|----------------|-------------------|
| **Installation** | Container Docker | Package système natif |
| **Gestion** | `docker exec gitlab` | `gitlab-ctl` |
| **Configuration** | Variables d'environnement | `/etc/gitlab/gitlab.rb` |
| **Performances** | Plus lent (overhead Docker) | Plus rapide (natif) |
| **RAM** | ~4GB minimum | ~4GB (plus efficace) |
| **Mise à jour** | Pull nouvelle image | `apt upgrade` |
| **Logs** | `docker logs gitlab` | `gitlab-ctl tail` |
| **Runner Executor** | Docker-in-Docker | Shell |

## 🆕 Nouvelle Installation

### Composants Installés

1. **GitLab CE** (Omnibus package)
   - Installation via repository officiel GitLab
   - Configuration dans `/etc/gitlab/gitlab.rb`
   - Gestion via `gitlab-ctl`

2. **GitLab Runner** (Native package)
   - Installation via repository officiel GitLab Runner  
   - Executor: **shell** (au lieu de docker)
   - Service système natif

3. **Postfix** (pour les emails)
   - Configuration automatique pour delivery local

## 🔧 Commandes GitLab (Barebone)

### Gestion de GitLab

```bash
# Vérifier le status
gitlab-ctl status

# Reconfigurer après modification de gitlab.rb
gitlab-ctl reconfigure

# Redémarrer tous les services
gitlab-ctl restart

# Redémarrer un service spécifique
gitlab-ctl restart nginx

# Voir les logs
gitlab-ctl tail

# Voir les logs d'un service spécifique
gitlab-ctl tail nginx
```

### Gestion de GitLab Runner

```bash
# Lister les runners
gitlab-runner list

# Vérifier le status du service
systemctl status gitlab-runner

# Voir les logs
journalctl -u gitlab-runner -f
```

## 📝 Fichiers de Configuration

### GitLab

- **Config principale** : `/etc/gitlab/gitlab.rb`
- **Password initial** : `/etc/gitlab/initial_root_password`
- **Credentials sauvegardés** : `/root/gitlab_credentials.txt`
- **Logs** : `/var/log/gitlab/`

### GitLab Runner

- **Config** : `/etc/gitlab-runner/config.toml`
- **Script registration** : `/tmp/register_runner.sh`

## 🚀 Déploiement

### Option 1 : Déploiement Complet

```bash
cd /Users/vladimir/Documents/GitHub/SAE6.DEVCLOUD.01/scripts
./deploy_all.sh
```

### Option 2 : Juste GitLab (si déjà déployé)

```bash
cd /Users/vladimir/Documents/GitHub/SAE6.DEVCLOUD.01/ansible
ansible-playbook -i inventory/hosts.ini playbook_gitlab.yml
```

## ⏱️ Temps d'Installation

- **GitLab CE** : ~5-7 minutes (au lieu de 10-15 avec Docker)
- **GitLab Runner** : ~1 minute
- **Total** : ~6-8 minutes

## 📊 Avantages du Barebone

### ✅ Performance

- **Démarrage plus rapide** : Pas de temps de boot du container
- **Moins de RAM** : Pas d'overhead Docker
- **I/O plus rapide** : Accès direct au filesystem

### ✅ Simplicité

- **Commandes directes** : `gitlab-ctl` au lieu de `docker exec`
- **Logs centralisés** : `journalctl` et `/var/log/gitlab/`
- **Service système** : Intégration avec systemd

### ✅ Production-Ready

- **Recommandé par GitLab** : Installation officielle pour production
- **Mises à jour simples** : `apt upgrade gitlab-ce`
- **Backups faciles** : `gitlab-backup create`

## 🔐 Sécurité

### Credentials GitLab

```bash
# Récupérer le password root
ssh root@<gitlab-ip> 'cat /root/gitlab_credentials.txt'

# Ou directement
ssh root@<gitlab-ip> 'cat /etc/gitlab/initial_root_password'
```

### Enregistrement du Runner

1. Accéder à GitLab: http://gitlab.local
2. Aller à: **Settings > CI/CD > Runners > New instance runner**
3. Copier le token
4. Sur le serveur GitLab:
   ```bash
   nano /tmp/register_runner.sh
   # Remplacer YOUR_REGISTRATION_TOKEN_HERE
   /tmp/register_runner.sh
   ```

## 🔍 Vérification Post-Installation

```bash
# SSH sur le serveur GitLab
ssh root@10.129.5.166

# Vérifier GitLab
gitlab-ctl status
# Tous les services doivent être "run"

# Tester l'API
curl http://localhost/-/health
# Doit retourner: {"status":"ok"}

# Vérifier le Runner
gitlab-runner list
systemctl status gitlab-runner
```

## 🛠️ Troubleshooting

### GitLab ne démarre pas

```bash
# Vérifier les logs
gitlab-ctl tail

# Reconfigurer
gitlab-ctl reconfigure

# Redémarrer
gitlab-ctl restart
```

### Problème de mémoire

```bash
# Vérifier l'utilisation
free -h

# GitLab recommande minimum 4GB RAM
# Assurez-vous que la VM a au moins 8GB (comme configuré)
```

### Runner ne s'enregistre pas

```bash
# Vérifier que GitLab est accessible
curl http://gitlab.local/-/health

# Vérifier le service runner
systemctl status gitlab-runner

# Essayer l'enregistrement manuel
gitlab-runner register \
  --url "http://gitlab.local" \
  --registration-token "VOTRE_TOKEN"
```

## 📦 Prochaines Étapes

1. **Déployer** : `./deploy_all.sh`
2. **Accéder à GitLab** : http://gitlab.local (ou via IP)
3. **Login** : root / (password from `/etc/gitlab/initial_root_password`)
4. **Enregistrer le Runner** : Suivre les étapes ci-dessus
5. **Déployer l'app** : Lancer `playbook_deploy.yml`

## 🎓 Pour la SAÉ

### Points Forts à Mentionner

- **Installation Production-Grade** : Barebone recommandé par GitLab
- **Performance Optimale** : Pas d'overhead Docker
- **Gestion Professionnelle** : `gitlab-ctl` utilisé en entreprise
- **Scalabilité** : Plus facile à scaler en barebone

### Démonstration

1. Montrer `gitlab-ctl status`
2. Modifier `/etc/gitlab/gitlab.rb`
3. `gitlab-ctl reconfigure`
4. Montrer les logs avec `gitlab-ctl tail`

---

**Date** : 2026-02-11  
**Version** : 2.0 - Barebone Installation  
**Durée d'installation** : ~6-8 minutes
