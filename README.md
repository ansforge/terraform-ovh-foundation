# 🏗️ Infrastructure OVHcloud - Compute (Production)

Ce dépôt Terraform gère la couche compute de l’infrastructure de production sur OVHcloud/OpenStack.  
Il permet de déployer et configurer les machines virtuelles (VMs) de la Landing Zone, avec leurs interfaces réseau, volumes additionnels et clés SSH.

---

# 🏗️ Architecture Compute

Le projet déploie plusieurs types de VMs avec des rôles distincts :

| VM        | Nom sur OpenStack         | Rôle                               | Disque additionnel | Réseau(x) principal(aux) |
|-----------|---------------------------|------------------------------------|--------------------|--------------------------|
| tfansible | infra-prod-tfansible01    | Gestion / Automation (Ansible)      | 0 GB               | prod-production-infra-app-10.11.90.0/24 |
| proxy     | infra-prod-proxy01        | Proxy Squid (DMZ + App)            | 50 GB              | prod-production-dmz-exposed-10.11.30.0/24, prod-production-infra-app-10.11.90.0/24 |
| repo      | infra-prod-repo01         | Repository interne                 | 150 GB             | prod-production-infra-app-10.11.90.0/24 |
| freeipa   | infra-prod-freeipa01      | Active Directory / Identity        | 0 GB               | prod-production-infra-app-10.11.90.0/24 |

Chaque VM reçoit automatiquement :
- Ses ports réseau avec IPs fixes
- Ses tags de métadonnées

---

# 🛠️ Composants Techniques

- **Provider OVH** : configuration des projets Public Cloud si nécessaire  
- **Provider OpenStack** : création des VMs, keypairs SSH, ports réseau et volumes  
- **Provider TLS** : génération locale des clés SSH  

---

# 🔑 Gestion des clés SSH

Pour chaque VM :
- Une clé SSH est générée via le provider `tls`
- Elle est injectée dans OpenStack comme keypair

Récupération des clés privées :

terraform output -raw private_keys

---

# 💾 Volumes additionnels

Les VMs disposant d’un disque supplémentaire sont automatiquement attachées via :

- \`openstack_compute_volume_attach_v2\`

---

# 🔐 Gestion des Secrets (Vault)

Le projet utilise des données éphémères Vault pour éviter de stocker les identifiants dans le state :

- \`iacrunner-prod/openstack_key\` : Credentials OpenStack (ID / Secret)

---

# 🚀 Déploiement

## Pré-requis

- Terraform >= 1.5
- Accès OpenStack via Application Credential
- Backend S3 configuré pour le state
- Vault configuré pour récupérer les secrets OpenStack

---

## Exemple d’exécution

### Initialiser Terraform

terraform init -backend-config=backend.tf

### Appliquer la configuration

terraform apply -var-file=compute.tfvars

---

# 📤 Outputs Terraform

| Output              | Description |
|--------------------|------------|
| private_keys       | Clés privées SSH des VMs (sensible) |
| instance_ids       | IDs OpenStack des instances |
| keypair_names      | Noms des keypairs créés |
| vm_network_details | Détails des ports et IPs des VMs |

