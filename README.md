# Virtual-Machines

Système de scripts pour créer, provisionner et récupérer rapidement mes VM de
cybersécurité (Debian, Kali, Ubuntu), sur Fedora + KVM/QEMU/libvirt.

**Objectif** : si je perds tout (kernel panic, réinstall, disque mort), je
dois pouvoir reconstruire un environnement fonctionnel en quelques commandes,
sans dépendre de fichiers `.qcow2` sauvegardés précieusement — seulement de
ce dépôt Git + une poignée d'URLs publiques.

## Structure

```
Virtual-Machines/
├── bootstrap-host.sh       # Remet en place libvirt/KVM après une install fraîche
├── debian/
│   ├── setup-template.sh   # Télécharge le template cloud Debian 13
│   └── vm-create.sh        # Clone COW + cloud-init → VM Debian en ~1 min
├── kali/
│   ├── setup-kali.sh       # Télécharge l'image QEMU officielle Kali
│   └── start-kali.sh       # Démarre/recrée la VM Kali (Makefile disponible)
└── ubuntu/
    ├── Vagrantfile         # Template minimal (RAM/CPU/pool paramétrables)
    ├── install-vagrant.sh  # Installe Vagrant + plugin vagrant-libvirt
    ├── setup-box.sh        # Enregistre la box dfir-ubuntu-base depuis le drive
    ├── new-ubuntu-lab.sh   # Crée un dossier de lab isolé (plusieurs VM possibles)
    └── labs/                # Dossiers générés, un par VM Ubuntu active
```

## Philosophie

- **Debian** : template cloud officiel en lecture seule + clone COW + cloud-init.
  Rapide, jetable, reproductible à l'infini sans jamais toucher au template.
- **Kali** : image QEMU officielle pré-construite, pas de clone COW — VM
  éphémère, recréée à volonté, aucun besoin de préserver un état.
- **Ubuntu** : box Vagrant custom (`dfir-ubuntu-base`), construite via Packer
  dans un **autre dépôt** (voir section Ubuntu ci-dessous). Vagrant gère son
  propre clone COW en interne (visible via `backing file` dans `qemu-img info`).

Les trois mécanismes sont différents par choix, pas par accident — chaque OS
a le pipeline le plus adapté à son usage réel plutôt qu'un système unique
forcé sur les trois.

## Récupération complète après perte totale (kernel panic, réinstall...)

```bash
# 1. Cloner ce dépôt
git clone <url-de-ce-repo> ~/My_codes_and_Projects/Virtual-Machines
cd ~/My_codes_and_Projects/Virtual-Machines

# 2. Remettre en place libvirt/KVM/pool/réseau (idempotent, sûr à relancer)
chmod +x bootstrap-host.sh
./bootstrap-host.sh
# /!\ Si le script ajoute de nouveaux groupes, déconnecte-toi/reconnecte-toi

# 3. Régénérer une clé SSH dédiée au lab (si l'ancienne est perdue)
ssh-keygen -t ed25519 -f ~/.ssh/lab_vms -N "" -C "adrien@lab-vms"

# 4. Debian — télécharger le template puis créer une VM
cd debian && chmod +x setup-template.sh vm-create.sh
./setup-template.sh
./vm-create.sh mavm 2048 2

# 5. Kali — télécharger l'image officielle
cd ../kali && chmod +x setup-kali.sh start-kali.sh
./setup-kali.sh          # version par défaut 2026.2, ou ./setup-kali.sh <version>
make recreate            # interactif : nom, RAM, vCPUs

# 6. Ubuntu — nécessite la box .box sauvegardée sur drive externe
cd ../ubuntu && chmod +x install-vagrant.sh setup-box.sh new-ubuntu-lab.sh
./install-vagrant.sh
./setup-box.sh /chemin/vers/drive/dfir-ubuntu-base.box
./new-ubuntu-lab.sh monlab 4096 4
```

Si le drive externe contenant la box Ubuntu est **aussi** perdu, voir
[ubuntu/README.md](ubuntu/README.md) pour la procédure de rebuild complète
depuis Packer (dans l'autre dépôt).

## Détails par OS

- [debian/README.md](debian/README.md) *(à rédiger si besoin de plus de détail)*
- [ubuntu/README.md](ubuntu/README.md)
- [kali/README.md](kali/README.md) *(à rédiger si besoin de plus de détail)*

## Problèmes déjà rencontrés

Voir [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — piège `qemu:///session` vs
`qemu:///system`, réseau `default` non auto-créé, permissions de pool,
`instance-id` cloud-init dupliqué, timeout sudo pendant `vagrant up`, etc.
