# MedSearch — Infrastructure Windows Server Haute Disponibilité

> Conception et déploiement d'une infrastructure d'entreprise complète sous Windows Server pour une société fictive de recherche médicale répartie sur deux sites géographiques.

---

## Sommaire

- [Contexte](#contexte)
- [Architecture](#architecture)
- [Prérequis](#prérequis)
- [Réseau](#réseau)
- [Haute disponibilité](#haute-disponibilité)
- [Sites web IIS — Windows Containers](#sites-web-iis--windows-containers)
- [Surveillance](#surveillance)
- [Administration à distance](#administration-à-distance)
- [Communication inter-sites](#communication-inter-sites)
- [Demande spéciale — Dashboard web](#demande-spéciale--dashboard-web)
- [Scripts](#scripts)
- [Compétences couvertes](#compétences-couvertes)

---

## Contexte

Ce projet a été réalisé dans le cadre du Master 1 **Systèmes, Réseaux & Sécurité** à SUPINFO Paris.

MedSearch est une société fictive spécialisée dans la recherche médicale, implantée sur deux sites géographiques — **Caen** (datacenter principal) et **Saint-Cénéri-le-Gérei** (site distant). Avant ce projet, aucun système d'information centralisé n'existait : les employés partageaient leurs documents via des clés USB et un seul administrateur supervisait l'ensemble du parc informatique.

L'objectif était de construire une infrastructure de base haute disponibilité, sécurisée et administrable à distance, capable d'héberger l'ensemble des futurs services de l'entreprise (WSUS, WDS, messagerie, DFS, etc.).

---

## Architecture

```
PROXMOX VE (Bare Metal)
│
├── WS-DC01        → AD DS | DNS | DHCP | iSCSI Target | RRAS VPN | Dashboard Web
├── WS-HV01        → Nœud Hyper-V 1 (Cluster) | RDS Session Host | Docker
└── WS-HV02        → Nœud Hyper-V 2 (Cluster)

MedSearch-Cluster (Failover Cluster)
└── Cluster Shared Volume — Stockage iSCSI 10 GB

Réseaux virtuels (Proxmox Linux Bridges)
├── vmbr1 — Gestion        (10.10.1.0/24)
├── vmbr2 — Stockage iSCSI (10.10.2.0/24)
└── vmbr3 — VMs Hyper-V    (10.10.3.0/24)
```

Proxmox VE joue ici le rôle du matériel physique sous-jacent (virtualisation imbriquée), permettant de simuler une infrastructure de production sur un environnement de lab.

---

## Prérequis

- Windows Server 2022 Standard Evaluation
- Hyperviseur supportant la virtualisation imbriquée (Proxmox VE 9.x)
- Rôle Hyper-V avec virtualisation des instructions CPU exposée (`cpu: host` dans Proxmox)
- Module PowerShell `FailoverClusters`
- Docker Engine pour Windows Containers

---

## Réseau

| Bridge | Rôle | Plage |
|---|---|---|
| vmbr1 | Gestion (Active Directory, administration) | 10.10.1.0/24 |
| vmbr2 | Stockage iSCSI | 10.10.2.0/24 |
| vmbr3 | Réseau des VMs Hyper-V / Containers | 10.10.3.0/24 |

| Machine | vmbr1 | vmbr2 | vmbr3 |
|---|---|---|---|
| WS-DC01 | 10.10.1.1 | 10.10.2.1 | — |
| WS-HV01 | 10.10.1.2 | 10.10.2.2 | 10.10.3.2 |
| WS-HV02 | 10.10.1.3 | 10.10.2.3 | 10.10.3.3 |

La séparation des flux garantit qu'une saturation du trafic iSCSI n'impacte pas les communications de gestion du cluster.

---

## Haute disponibilité

**Composants :**
- Failover Cluster Windows Server (`MedSearch-Cluster`) — 2 nœuds (WS-HV01, WS-HV02)
- Stockage partagé iSCSI Target hébergé sur WS-DC01 (volume 10 GB)
- Cluster Shared Volume (CSV) pour accès simultané au stockage par les deux nœuds
- VM-Switch Hyper-V identique sur les deux nœuds (prérequis pour la Live Migration)

**Commandes de vérification :**
```powershell
Get-Cluster
Get-ClusterNode
Get-ClusterSharedVolume
Get-ClusterResource
```

En cas de panne d'un nœud, le second prend automatiquement le relais (basculement automatique du cluster), sans intervention manuelle.

---

## Sites web IIS — Windows Containers

**Problématique :** déployer rapidement un nouveau site web par projet de recherche, avec une empreinte système minimale sur les hôtes Hyper-V.

**Solution :** Windows Containers (Docker) hébergeant l'image officielle `mcr.microsoft.com/windows/servercore/iis`.

Script de déploiement en une commande (voir [`Deploy-IISSite.ps1`](#scripts)) :
```powershell
.\Deploy-IISSite.ps1 -SiteName "site-recherche-1" -IPAddress "10.10.3.10" -Port 80
```

---

## Surveillance

Deux mécanismes complémentaires, tournant via tâches planifiées :

1. **Alertes de performance** (WS-HV01) — `Send-Alert.ps1` mesure CPU/RAM toutes les 5 minutes et journalise les dépassements de seuil.
2. **Centralisation des logs** (WS-DC01) — `Collect-Logs.ps1` collecte via PowerShell Remoting les événements critiques de WS-HV01 et WS-HV02 toutes les 5 minutes.

---

## Administration à distance

- **RRAS VPN SSTP** sur WS-DC01 — accès VPN chiffré via le port 443 (HTTPS), traversant tous les pare-feux sans configuration particulière.
- **RDS Session Host** sur WS-HV01 — bureau à distance complet pour l'administration des serveurs.

```powershell
Get-Service RemoteAccess
Get-VpnConnection -Name "MedSearch-VPN"
```

---

## Communication inter-sites

**Contrainte :** aucune configuration requise sur les postes des employés du site distant (Saint-Cénéri-le-Gérei).

**Solution :** VPN SSTP — protocole nativement supporté par Windows, encapsulé dans du HTTPS (port 443), chiffrement TLS de bout en bout.

---

## Demande spéciale — Dashboard web

Script PowerShell (`Generate-Dashboard.ps1`) générant une page HTML dynamique affichant :
- Statut de connectivité de chaque serveur (ping)
- Les 5 derniers événements critiques/avertissement par serveur (PowerShell Remoting)
- Bouton d'escalade vers le support pour chaque événement

---

## Scripts

| Script | Emplacement | Fonction |
|---|---|---|
| `Deploy-IISSite.ps1` | WS-HV01 | Déploiement d'un site IIS via container Docker |
| `Send-Alert.ps1` | WS-HV01 | Alerte CPU/RAM avec journalisation |
| `Collect-Logs.ps1` | WS-DC01 | Centralisation des logs système distants |
| `Generate-Dashboard.ps1` | WS-DC01 | Génération du dashboard HTML de supervision |

Voir le dossier [`scripts/`](./scripts) pour le code source complet.

---

## Compétences couvertes

`Windows Server 2022` `Active Directory` `Failover Clustering` `Hyper-V` `iSCSI` `Windows Containers` `Docker` `PowerShell` `RRAS / VPN SSTP` `RDS` `PowerShell Remoting` `Monitoring` `Proxmox VE`

---

*Projet réalisé par Jacques Masasi & David Ndamba — M1 Systèmes, Réseaux & Sécurité, SUPINFO Paris.*
