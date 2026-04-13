# 🖥️ terraform-ovh-foundation

**Provisionnement des machines virtuelles d'infrastructure (Landing Zone) sur OVH Cloud via Terraform — ANS Forge**

Ce dépôt Terraform provisionne les VMs fondatrices de la plateforme : contrôleur Ansible/Terraform, serveur FreeIPA, serveur de dépôts, et proxy Squid. Il gère la création des instances OpenStack, des clés SSH dynamiques, des ports réseau multi-NIC, des volumes de stockage additionnels, et l'attachement aux VLANs vRack.

---

## 📑 Table des matières

- [Architecture](#-architecture)
- [Prérequis](#-prérequis)
- [Arborescence du projet](#-arborescence-du-projet)
- [Branches et environnements](#-branches-et-environnements)
- [Providers utilisés](#-providers-utilisés)
- [Module compute](#-module-compute)
- [Variables](#-variables)
- [Inventaire des VMs](#-inventaire-des-vms)
- [Backend S3 (state distant)](#-backend-s3-state-distant)
- [Commandes de lancement](#-commandes-de-lancement)
- [Commandes de test et vérification](#-commandes-de-test-et-vérification)
- [Gestion des secrets (Vault)](#-gestion-des-secrets-vault)
- [Ajouter / modifier une VM](#-ajouter--modifier-une-vm)
- [Récupérer la clé SSH d'une VM](#-récupérer-la-clé-ssh-dune-vm)
- [Protections lifecycle](#-protections-lifecycle)
- [Dépannage](#-dépannage)
- [Contribution](#-contribution)

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      HashiCorp Vault                             │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ iacrunner-*/openstack_key                                │   │
│  │ (OS_AUTH_URL, OS_APPLICATION_CREDENTIAL_ID/SECRET)       │   │
│  └──────────────────────────────────────────────────────────┘   │
└───────────────────────────────┬─────────────────────────────────┘
                                │ lecture (ephemeral)
                                ▼
┌───────────────────────────────────────────────────────────────────┐
│                    Terraform (ce repo)                             │
│                                                                   │
│  main.tf ──► module "instances" (compute)                         │
│               ├── tls_private_key (RSA 4096 par VM)               │
│               ├── openstack_compute_keypair_v2                    │
│               ├── openstack_networking_port_v2 (multi-NIC)        │
│               ├── openstack_compute_instance_v2 (VMs)             │
│               ├── openstack_blockstorage_volume_v3 (extra disks)  │
│               ├── openstack_compute_volume_attach_v2              │
│               └── openstack_compute_interface_attach_v2 (prod)    │
└───────────────────────────────┬───────────────────────────────────┘
                                │
                                ▼
┌───────────────────────────────────────────────────────────────────┐
│                    OVH Public Cloud / OpenStack                    │
│                                                                   │
│  ┌───────────────┐ ┌──────────────┐ ┌────────────┐ ┌──────────┐ │
│  │ tfansible01   │ │ proxy01      │ │ repo01     │ │ freeipa01│ │
│  │ (Ansible/TF)  │ │ (Squid)     │ │ (Repos DNF)│ │ (IDM)    │ │
│  │ Ext-Net +     │ │ 3 NICs      │ │ 1 NIC      │ │ 1 NIC    │ │
│  │ infra_app     │ │ + 50GB disk │ │ + 150GB    │ │          │ │
│  └───────────────┘ └──────────────┘ └────────────┘ └──────────┘ │
│         │                  │               │             │        │
│    ┌────▼──────────────────▼────────────��──▼─────────────▼───┐   │
│    │                  VLANs vRack                             │   │
│    │  infra_app / dmz_admin / dmz_transit / dmz_exposed      │   │
│    └─────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────┘
```

---

## 📋 Prérequis

| Outil | Version | Description |
|---|---|---|
| **Terraform** | ≥ 1.10 | Infrastructure as Code (support `ephemeral` resources) |
| **HashiCorp Vault** | Accès actif | Credentials OpenStack |
| **OVH Public Cloud** | Projet actif | Avec vRack et réseaux déjà créés (`terraform-ovh-network`) |
| **Image AlmaLinux** | Uploadée dans OpenStack | Image de base pour les VMs |

### Variables d'environnement requises

```bash
# Vault
export VAULT_ADDR="https://vault.example.com"
export VAULT_TOKEN="hvs.xxxxx"

# Backend S3 (pour le state Terraform)
export AWS_ACCESS_KEY_ID="<s3_access_key>"
export AWS_SECRET_ACCESS_KEY="<s3_secret_key>"
```

---

## 🗂️ Arborescence du projet

```
terraform-ovh-foundation/
├── main.tf                          # Providers, appel module compute
├── backend.tf                       # Configuration backend S3 distant (tfstate)
├── variables.tf                     # Variables racine (region, ovh_project_id, vms)
├── compute.tfvars                   # Définition de toutes les VMs et de leurs interfaces
├── .gitignore                       # Exclusion .terraform/, *.tfstate*, *.pem
├── modules/
│   └── compute/
│       ├── main.tf                  # Ressources : clés SSH, ports, instances, volumes, attachements
│       ├── variables.tf             # Variables du module
│       └── output.tf                # Outputs : instance_ids, instance_ips
└── README.md
```

---

## 🌿 Branches et environnements

| Branche | Environnement | Vault Mount | Région OVH | Bucket tfstate |
|---|---|---|---|---|
| `amont` | Pré-production | `iacrunner-amont` | `SBG5` (Strasbourg) | `infra-amont-sto-object-tf01` |
| `prod` | Production | `iacrunner-prod` | `RBX-A` (Roubaix) | `infra-prod-sto-object-tf01` |
| `main` | — | — | — | Branche par défaut (documentation) |

### Différences clés entre branches

| Paramètre | `amont` | `prod` |
|---|---|---|
| `ovh_project_id` | `a5a3658023e146e78a22afd04601b813` | `2b264defd5244f52b8edbd6c9239a325` |
| `region` | `SBG5` | `RBX-A` |
| Préfixe nommage VM | `infra-amont-*` | `infra-prod-*` |
| Préfixe réseaux | `preprod-amont-*` | `prod-production-*` |
| Ext-Net (tfansible) | Oui | Oui |
| Attachement NIC secondaires | `dynamic "network"` dans l'instance | `openstack_compute_interface_attach_v2` séparé |

---

## 🔌 Providers utilisés

| Provider | Source | Version | Usage |
|---|---|---|---|
| **openstack** | `terraform-provider-openstack/openstack` | `>= 1.53.0` | Instances, ports, volumes, keypairs |
| **vault** | `hashicorp/vault` | `>= 3.25.0` | Lecture des credentials OpenStack (ephemeral) |
| **ovh** | `ovh/ovh` | `>= 0.40.0` | Déclaré pour compatibilité |
| **tls** | `hashicorp/tls` | latest | Génération dynamique des clés SSH RSA 4096 |

---

## 📦 Module compute

### `modules/compute/`

Module qui provisionne les VMs d'infrastructure avec gestion multi-NIC, volumes additionnels, et clés SSH dynamiques.

#### Ressources créées (par VM)

| # | Ressource | Type | Description |
|---|---|---|---|
| 1 | `tls_private_key.vm_key` | Clé SSH | RSA 4096 bits, générée dynamiquement par VM |
| 2 | `openstack_compute_keypair_v2.vm_kp` | Keypair OpenStack | Clé publique enregistrée (nom: `vm-<key>-key`) |
| 3 | `openstack_networking_network_v2.networks` | Data source | Résolution des réseaux par nom → UUID |
| 4 | `openstack_networking_subnet_v2.subnets` | Data source | Résolution des subnets (exclu `Ext-Net`) |
| 5 | `openstack_networking_port_v2.vm_ports` | Port réseau | Port par interface avec IP fixe, `port_security_enabled = false` |
| 6 | `openstack_compute_instance_v2.vm` | Instance | VM avec injection des ports réseau |
| 7 | `openstack_blockstorage_volume_v3.extra_disk` | Volume | Disque additionnel (si `extra_disk_gb > 0`) |
| 8 | `openstack_compute_volume_attach_v2.attach_extra` | Attachement volume | Monte le volume additionnel sur l'instance |
| 9 | `openstack_compute_interface_attach_v2.ai` | Attachement NIC | (prod) Attache les interfaces réseau secondaires après création |

#### Points techniques importants

- **`port_security_enabled = false`** : Désactivé sur tous les ports pour permettre le routage (proxy, IPA)
- **`prevent_destroy = true`** : Actif sur les instances, ports et volumes — empêche les destructions accidentelles
- **`ignore_changes = all`** : La plupart des ressources ignorent les changements pour éviter les re-créations en cascade
- **`Ext-Net`** : Le réseau public est traité différemment (pas de port fixe, accès Internet direct)
- **Multi-NIC (prod)** : Utilise `openstack_compute_interface_attach_v2` pour attacher les interfaces secondaires après la création de l'instance
- **Multi-NIC (amont)** : Utilise un bloc `dynamic "network"` directement dans l'instance

#### Outputs du module

| Output | Description |
|---|---|
| `instance_ids` | Map `{vm_key => instance_uuid}` des IDs OpenStack |
| `instance_ips` | Map `{vm_key_network => ip}` des IPs fixées pour chaque port |

---

## 📝 Variables

### Variables racine (`variables.tf`)

| Variable | Type | Description |
|---|---|---|
| `region` | `string` | Région OVH Public Cloud (SBG5, RBX-A) |
| `ovh_project_id` | `string` | ID du projet Public Cloud OVH |
| `vms` | `map(object)` | Map des VMs à déployer |

### Structure d'une VM

```hcl
variable "vms" {
  type = map(object({
    name          = string              # Nom de l'instance
    flavor_id     = string              # UUID du flavor (taille VM)
    image_id      = string              # UUID de l'image AlmaLinux
    key_name      = string              # Nom de la clé SSH (généré automatiquement)
    extra_disk_gb = optional(number, 0) # Taille du disque additionnel (0 = pas de disque)
    networks      = list(object({       # Interfaces réseau
      name    = string                  # Nom du réseau OpenStack ou "Ext-Net"
      ip      = string                  # IP fixe ("" pour Ext-Net / DHCP)
      enabled = bool                    # Interface active
    }))
    tags = map(string)                  # Métadonnées (Owner, Env, App)
  }))
}
```

---

## 🖥️ Inventaire des VMs

### Production (`prod` — `RBX-A`)

| Clé | Nom | Application | Interfaces | Extra Disk | IP principale |
|---|---|---|---|---|---|
| `tfansible` | `infra-prod-tfansible01` | Ansible / Terraform Controller | `Ext-Net` + `infra-app` | — | `10.11.90.14` |
| `proxy` | `infra-prod-proxy01` | Proxy Squid | `dmz-admin` + `dmz-transit` + `dmz-exposed` | **50 GB** | `10.11.52.11` |
| `repo` | `infra-prod-repo01` | Serveur dépôts AlmaLinux | `infra-app` | **150 GB** | `10.11.90.12` |
| `freeipa` | `infra-prod-freeipa01` | FreeIPA IDM (DNS, LDAP, Kerberos) | `infra-app` | — | `10.11.90.13` |

#### Détail des interfaces — Production

**tfansible01** (2 NIC) :
| Interface | Réseau | IP |
|---|---|---|
| eth0 | `Ext-Net` | DHCP (IP publique) |
| eth1 | `prod-production-infra-app-10.11.90.0-24` | `10.11.90.14` |

**proxy01** (3 NIC + 50GB volume) :
| Interface | Réseau | IP |
|---|---|---|
| eth0 | `prod-production-dmz-admin-10.11.52.0-24` | `10.11.52.11` |
| eth1 | `prod-production-dmz-transit-10.11.70.0-24` | `10.11.70.11` |
| eth2 | `prod-production-dmz-exposed-10.11.30.0-24` | `10.11.30.11` |

**repo01** (1 NIC + 150GB volume) :
| Interface | Réseau | IP |
|---|---|---|
| eth0 | `prod-production-infra-app-10.11.90.0-24` | `10.11.90.12` |

**freeipa01** (1 NIC) :
| Interface | Réseau | IP |
|---|---|---|
| eth0 | `prod-production-infra-app-10.11.90.0-24` | `10.11.90.13` |

### Pré-production (`amont` — `SBG5`)

| Clé | Nom | Application | Interfaces | Extra Disk | IP principale |
|---|---|---|---|---|---|
| `tfansible` | `infra-amont-tfansible01` | Ansible / Terraform | `Ext-Net` + `infra-app` | — | `10.12.90.14` |
| `proxy` | `infra-amont-proxy01` | Proxy Squid | `dmz-admin` + `dmz-transit` + `dmz-exposed` | **50 GB** | `10.12.52.11` |
| `repo` | `infra-amont-repo01` | Serveur dépôts | `infra-app` | **150 GB** | `10.12.90.12` |
| `freeipa` | `infra-amont-freeipa01` | FreeIPA IDM | `infra-app` | — | `10.12.90.13` |

---

## 💾 Backend S3 (state distant)

### Branche `amont`

```hcl
terraform {
  backend "s3" {
    bucket = "infra-amont-sto-object-tf01"
    key    = "infra-amont-compute.tfstate"
    region = "sbg"
    endpoints = { s3 = "https://s3.sbg.io.cloud.ovh.net/" }
  }
}
```

### Branche `prod`

```hcl
terraform {
  backend "s3" {
    bucket = "infra-prod-sto-object-tf01"
    key    = "infra-porduction-compute.tfstate"
    region = "rbx"
    endpoints = { s3 = "https://s3.rbx.io.cloud.ovh.net/" }
  }
}
```

---

## 🚀 Commandes de lancement

### Déploiement standard

```bash
# 1. Se positionner sur la branche de l'environnement
git checkout amont   # ou prod

# 2. Configurer les variables d'environnement
export VAULT_ADDR="https://vault.example.com"
export AWS_ACCESS_KEY_ID="<s3_access_key>"
export AWS_SECRET_ACCESS_KEY="<s3_secret_key>"

# 3. Initialiser Terraform
terraform init

# 4. Planifier les changements
terraform plan -var-file="compute.tfvars"

# 5. Appliquer les changements
terraform apply -var-file="compute.tfvars"
```

### Cibler une VM spécifique

```bash
# Planifier uniquement la VM tfansible
terraform plan -var-file="compute.tfvars" \
  -target='module.instances.openstack_compute_instance_v2.vm["tfansible"]'

# Planifier une VM et ses ports/volumes
terraform plan -var-file="compute.tfvars" \
  -target='module.instances.openstack_compute_instance_v2.vm["proxy"]' \
  -target='module.instances.openstack_blockstorage_volume_v3.extra_disk["proxy"]'
```

### Destruction (⚠️ PROTÉGÉ)

La plupart des ressources ont `prevent_destroy = true`. Pour détruire une VM :

1. Commenter `prevent_destroy = true` dans le module
2. Exécuter :
```bash
terraform destroy -var-file="compute.tfvars" \
  -target='module.instances.openstack_compute_instance_v2.vm["ma_vm"]'
```
3. **Remettre** `prevent_destroy = true` et commiter

> ⚠️ **ATTENTION** : La destruction d'une VM d'infrastructure impacte tous les services (DNS, repos, proxy, Ansible).

---

## 🧪 Commandes de test et vérification

```bash
# Valider la syntaxe
terraform validate

# Formater le code
terraform fmt -check -recursive
terraform fmt -recursive

# Lister les ressources dans le state
terraform state list

# Afficher le détail d'une VM
terraform state show 'module.instances.openstack_compute_instance_v2.vm["tfansible"]'

# Afficher les ports d'une VM
terraform state list | grep 'vm_ports.*tfansible'

# Afficher les volumes
terraform state list | grep 'extra_disk'

# Afficher les outputs
terraform output
terraform output -json

# Planifier en mode détaillé
terraform plan -var-file="compute.tfvars" -detailed-exitcode
# Exit code 0 = pas de changement
# Exit code 2 = changements détectés

# Graphe de dépendances
terraform graph | dot -Tpng > compute-graph.png
```

### Vérification côté OpenStack

```bash
# Lister les instances
openstack server list

# Détail d'une VM
openstack server show infra-prod-tfansible01

# Lister les volumes
openstack volume list

# Vérifier les ports d'une VM
openstack port list --server infra-prod-proxy01

# Vérifier la connectivité SSH
ssh -i tfansible.pem almalinux@<ip_publique>
```

---

## 🔐 Gestion des secrets (Vault)

### Secrets consommés (en lecture)

| Chemin Vault | Clés | Provenance |
|---|---|---|
| `iacrunner-*/openstack_key` | `OS_AUTH_URL`, `OS_APPLICATION_CREDENTIAL_ID`, `OS_APPLICATION_CREDENTIAL_SECRET` | Créé par `terraform-ovh-storage` |

### Vérification Vault

```bash
vault kv get iacrunner-amont/openstack_key
vault kv get iacrunner-prod/openstack_key
```

---

## 🔑 Récupérer la clé SSH d'une VM

Les clés SSH sont générées dynamiquement et stockées dans le state Terraform (sensible).

```bash
# Afficher la clé privée de la VM tfansible
terraform state show 'module.instances.tls_private_key.vm_key["tfansible"]' | grep private_key_pem

# Ou extraire directement via output (si configuré)
terraform output -json | jq -r '.instance_ids'

# Sauvegarder la clé dans un fichier
terraform state show 'module.instances.tls_private_key.vm_key["tfansible"]' \
  | grep -A1 'private_key_pem' | tail -1 > tfansible.pem
chmod 600 tfansible.pem

# Se connecter
ssh -i tfansible.pem almalinux@<ip>
```

> ⚠️ Ne jamais commiter les fichiers `.pem`. Ils sont exclus par le `.gitignore`.

---

## 🔒 Protections lifecycle

Ce repo utilise des protections `lifecycle` étendues pour éviter les destructions accidentelles :

| Ressource | `prevent_destroy` | `ignore_changes` | Raison |
|---|---|---|---|
| `tls_private_key.vm_key` | Non | `all` | Évite la re-génération de clé (perte d'accès SSH) |
| `openstack_compute_keypair_v2.vm_kp` | Non | `all` | Idem |
| `openstack_networking_port_v2.vm_ports` | **Oui** | `all` | Un port supprimé = interface réseau perdue |
| `openstack_compute_instance_v2.vm` | **Oui** | `user_data`, `network`, `key_pair`, `image_id`, `flavor_id`, `metadata`, `security_groups` | VM protégée contre toute suppression |
| `openstack_blockstorage_volume_v3.extra_disk` | **Oui** | `all` | Volume = données persistantes |
| `openstack_compute_volume_attach_v2` | Non | `all` | Attachement stable |
| `openstack_compute_interface_attach_v2` | Non | `all` | NIC secondaires stables (prod) |

---

## ➕ Ajouter / modifier une VM

### Ajouter une nouvelle VM

1. Éditer `compute.tfvars` et ajouter une entrée dans la map `vms` :

```hcl
vms = {
  # ... VMs existantes ...

  monitoring = {
    name          = "infra-prod-monitoring01"
    flavor_id     = "94d7bb57-156a-4e7d-8840-1e9e4bcbe304"
    image_id      = "587c721d-e39f-4061-8e42-059104b88f21"
    key_name      = "vm-monitoring-key"
    extra_disk_gb = 100
    networks = [
      { name = "prod-production-infra-app-10.11.90.0-24", ip = "10.11.90.20", enabled = true }
    ]
    tags = { Owner = "infra-team", Env = "prod", App = "monitoring" }
  }
}
```

2. Planifier et appliquer :
```bash
terraform plan -var-file="compute.tfvars"
terraform apply -var-file="compute.tfvars"
```

### Convention d'allocation IP

| Plage | Usage |
|---|---|
| `.1` à `.10` | Réservé (gateway, VIP) |
| `.11` à `.50` | VMs d'infrastructure (ce repo) |
| `.51` à `.100` | Pool DHCP (`terraform-ovh-network`) |
| `.251` à `.254` | Firewalls (`terraform-ovh-security`) |

### Ajouter un disque additionnel

Modifier `extra_disk_gb` dans `compute.tfvars` :

```hcl
extra_disk_gb = 200  # En GB
```

> **Note** : Le volume sera créé et attaché automatiquement. Il faudra ensuite le formater et monter via Ansible.

---

## 🔧 Dépannage

### Problèmes courants

| Problème | Cause probable | Solution |
|---|---|---|
| `Error: ephemeral resource not supported` | Terraform < 1.10 | Mettre à jour Terraform ≥ 1.10 |
| `Error: No network found with name` | Réseau pas encore créé | Déployer d'abord `terraform-ovh-network` |
| `Error: Instance cannot be destroyed` | `prevent_destroy = true` actif | Commenter temporairement `prevent_destroy` si la destruction est voulue |
| `Error: IP address already in use` | IP déjà prise par un autre port | Vérifier les IPs dans `compute.tfvars`, s'assurer qu'il n'y a pas de conflit |
| `Error: Quota exceeded` | Plus assez de ressources OVH | Augmenter les quotas dans le Manager OVH |
| VM créée mais pas joignable | Route ou firewall manquant | Vérifier les VLANs (`terraform-ovh-network`) et le firewall (`terraform-ovh-security`) |
| Disque additionnel non monté | Volume attaché mais pas formaté | Formater et monter via Ansible (`mkfs.xfs`, `mount`) |

### Commandes de diagnostic

```bash
# Debug complet
TF_LOG=DEBUG terraform plan -var-file="compute.tfvars" 2>&1 | tee debug.log

# Vérifier le state
terraform state pull | jq '.resources[] | .type + "." + .name'

# Importer une instance existante
terraform import \
  'module.instances.openstack_compute_instance_v2.vm["tfansible"]' \
  <instance_uuid>

# Importer un volume existant
terraform import \
  'module.instances.openstack_blockstorage_volume_v3.extra_disk["repo"]' \
  <volume_uuid>

# Taint pour forcer la re-création (attention : prevent_destroy!)
terraform taint 'module.instances.openstack_compute_instance_v2.vm["freeipa"]'
```

---

## 🤝 Contribution

1. Se positionner sur la branche de l'environnement :
   ```bash
   git checkout amont  # pré-production
   git checkout prod   # production
   ```
2. Créer une branche feature si nécessaire :
   ```bash
   git checkout -b feature/ajout-vm-monitoring amont
   ```
3. Valider avec `terraform validate` et `terraform fmt`
4. Planifier avec `terraform plan` pour vérifier l'impact
5. Créer une Pull Request vers la branche cible

### Conventions

- **Nommage des VMs** : `infra-<env>-<app><num>` (ex: `infra-prod-tfansible01`)
- **Clés de map** : nom court de l'application (ex: `tfansible`, `proxy`, `repo`, `freeipa`)
- **IPs** : plage `.11` à `.50` pour les VMs d'infrastructure
- **Tags obligatoires** : `Owner`, `Env`, `App`
- **Disques extra** : nommés `infra-prod-<key>-extra`

---

## 🔗 Dépendances et projets liés

| Repo | Relation | Description |
|---|---|---|
| [`terraform-ovh-storage`](https://github.com/ansforge/terraform-ovh-storage) | **Pré-requis** | Crée les credentials OpenStack et le bucket tfstate |
| [`terraform-ovh-network`](https://github.com/ansforge/terraform-ovh-network) | **Pré-requis** | Les VLANs/subnets doivent exister avant de créer les VMs |
| [`terraform-ovh-security`](https://github.com/ansforge/terraform-ovh-security) | **Pré-requis** | Les firewalls doivent être déployés pour le routage inter-VLAN |
| [`ansible-ovh`](https://github.com/ansforge/ansible-ovh) | **Post-déploiement** | Configuration des VMs après provisionnement |

### Ordre de déploiement global

```
1. terraform-ovh-storage     → Credentials + bucket tfstate
2. terraform-ovh-network     → VLANs et subnets vRack
3. terraform-ovh-security    → Firewalls Stormshield
4. terraform-ovh-foundation  → V
