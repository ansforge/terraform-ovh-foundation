Infrastructure OVHcloud - Compute / Foundation (Production)

Ce dépôt Terraform gère la couche compute de l’infrastructure OVHcloud :
- déploiement des machines virtuelles (VMs)
- gestion des interfaces réseau (multi-NIC)
- génération automatique des clés SSH
- attachement de volumes supplémentaires
- intégration complète avec la couche réseau existante

🏗️ Structure du Projet

modules/compute/ : Module principal gérant :
- création des VMs OpenStack
- génération des clés SSH (TLS)
- création des keypairs
- création des ports réseau
- attachement multi-réseaux
- gestion des volumes additionnels

backend.tf : Configuration du backend distant (S3 OVH Object Storage).

main.tf : Point d’entrée Terraform appelant le module compute.

variables.tf : Déclaration des variables globales.

compute.tfvars : Définition des machines virtuelles (infra, proxy, repo, etc.).

---

🔐 Intégration Vault

Les credentials OpenStack sont récupérés dynamiquement via Vault :

iacrunner-prod/openstack_key :
- OS_AUTH_URL
- OS_APPLICATION_CREDENTIAL_ID
- OS_APPLICATION_CREDENTIAL_SECRET

👉 Utilisation de secrets éphémères :
- aucun secret stocké dans Terraform
- aucune exposition dans le state
- sécurité maximale

---

🖥️ Architecture Compute

Déploiement des composants de la landing zone :

- tfansible → serveur Ansible / automation
- proxy → proxy (ex: Squid) en DMZ
- repo → repository interne (packages)
- freeipa → gestion des identités (IAM interne)

Caractéristiques :

- IPs statiques sur réseaux privés
- multi-interface réseau
- segmentation complète (DMZ / INFRA / APP)
- attachement disque optionnel

---

🌐 Intégration Réseau

Les VMs sont connectées aux réseaux créés dans :

👉 terraform-ovh-network

Types de réseaux utilisés :

- Ext-Net → accès public OVH
- infra_app → réseau interne infra
- dmz_admin / dmz_transit / dmz_exposed → zones DMZ

👉 Chaque VM peut avoir :
- 1 interface principale (boot)
- N interfaces secondaires (attachées dynamiquement)

---

⚙️ Fonctionnement technique

1. Génération des clés SSH

resource : tls_private_key

- 1 clé par VM
- RSA 4096 bits
- persistée dans le state (sensible)

---

2. Création KeyPair OpenStack

resource : openstack_compute_keypair_v2

- clé publique injectée
- utilisée pour accès SSH

---

3. Résolution des réseaux

data : openstack_networking_network_v2

- récupération des réseaux par NOM
- mutualisation pour toutes les VMs

---

4. Création des subnets

data : openstack_networking_subnet_v2

- utilisé pour assignation IP statique

---

5. Création des ports réseau

resource : openstack_networking_port_v2

- 1 port par interface
- IP statique si définie
- port_security désactivé

Spécificité :
- Ext-Net → pas d’IP fixée
- réseaux privés → IP obligatoire

---

6. Déploiement des VMs

resource : openstack_compute_instance_v2

- attachement via port principal
- metadata injectée (tags)
- lifecycle sécurisé (prevent_destroy)

---

7. Attachement multi-interface

resource : openstack_compute_interface_attach_v2

- attache les interfaces secondaires
- dynamique selon config

---

8. Gestion des volumes

resource : openstack_blockstorage_volume_v3

- disque supplémentaire optionnel
- attaché automatiquement à la VM

---

🪣 Backend Terraform

- Bucket : infra-prod-sto-object-tf01
- Région : RBX
- Endpoint : https://s3.rbx.io.cloud.ovh.net/

👉 Permet :
- centralisation du state
- cohérence infra globale
- collaboration

---

🚀 Utilisation

Pré-requis

1. Vault accessible :

export VAULT_ADDR=https://vault.xxx

2. Secret requis :

- iacrunner-prod/openstack_key

3. Réseau déjà déployé :
👉 dépend de terraform-ovh-network

---

Déploiement

terraform init  
terraform plan -var-file="compute.tfvars"  
terraform apply -var-file="compute.tfvars"

---

🔧 Variables

compute.tfvars :

region         = "RBX-A"
ovh_project_id = "2b264defd5244f52b8edbd6c9239a325"

vms = {
  tfansible = {
    name      = "infra-prod-tfansible01"
    flavor_id = "xxx"
    image_id  = "xxx"
    networks  = [...]
  }
}

👉 Chaque VM définit :

- nom
- flavor (CPU / RAM)
- image
- clé SSH
- réseaux + IP
- disque additionnel (optionnel)
- tags

---

📤 Outputs Terraform

instance_ids :
- IDs OpenStack des VMs

instance_ips :
- IPs associées à chaque interface

👉 Utilisable pour :
- Ansible
- inventaire dynamique
- monitoring
- bastion / accès

---

🛡️ Sécurité

- clés SSH générées automatiquement
- aucun mot de passe
- secrets via Vault uniquement
- ports réseau isolés
- prevent_destroy activé (anti-erreur humaine)

---

⚠️ Points d’attention

- les réseaux doivent exister (terraform-ovh-network)
- IPs doivent être disponibles
- Ext-Net ne supporte pas IP fixe via Terraform
- ne pas supprimer les ports (lifecycle)
- cohérence entre interfaces et firewall

---

🧪 Vérifications post-déploiement

Lister VMs :
openstack server list

Lister ports :
openstack port list

Lister volumes :
openstack volume list

Tester accès :
ssh -i <key> user@<ip>

---

🔄 Améliorations possibles

- cloud-init automatisé
- intégration Ansible automatique
- autoscaling (si besoin)
- monitoring (Prometheus / Grafana)
- gestion des backups volumes

---

👨‍💻 Auteur

Infrastructure Terraform OVHcloud – Layer compute (VMs + réseau + stockage) industrialisé pour production.
