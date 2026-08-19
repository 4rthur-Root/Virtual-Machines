# Troubleshooting

Problèmes réels rencontrés en construisant ce dépôt, avec la cause exacte et
le fix — pas des suppositions générales.

## `qemu:///session` vs `qemu:///system`

**Symptôme** : `virsh net-list --all` ou `virsh pool-list --all` (sans sudo)
n'affiche rien, alors que `sudo virsh ...` montre bien les ressources actives.

**Cause** : `virsh` sans argument se connecte par défaut à `qemu:///session`
(session utilisateur isolée), pas `qemu:///system` (le vrai daemon système
partagé). Ce sont deux univers séparés avec leurs propres pools/réseaux/VM.

**Fix** :
```bash
echo 'export LIBVIRT_DEFAULT_URI="qemu:///system"' >> ~/.zshrc
source ~/.zshrc
```
(`.zshrc`, pas `.bashrc`, si le shell par défaut est zsh — `source ~/.bashrc`
en zsh échoue avec `shopt: command not found`.)

## Popup de mot de passe après avoir fixé `LIBVIRT_DEFAULT_URI`

**Symptôme** : Polkit redemande le mot de passe à chaque commande `virsh`,
même sans sudo, une fois connecté à `qemu:///system`.

**Cause** : l'utilisateur n'est pas dans le groupe `libvirt` (être dans le
groupe `qemu` ne suffit pas pour l'autorisation Polkit).

**Fix** :
```bash
sudo usermod -aG libvirt $USER
# déconnexion/reconnexion de session requise, pas juste `newgrp`
```

## Réseau `default` introuvable après une install fraîche

**Symptôme** : `virsh net-list --all` vide, `virsh net-start default` échoue
avec `Network not found`.

**Cause** : sur les versions récentes de libvirt/Fedora, le réseau `default`
n'est plus auto-défini au premier démarrage de `libvirtd`.

**Fix** :
```bash
virsh net-define /usr/share/libvirt/networks/default.xml
virsh net-start default
virsh net-autostart default
```

## `error: failed to get network 'default'` malgré un `net-start` qui semble avoir marché

**Symptôme** : logs `journalctl -u libvirtd` montrent dnsmasq qui démarre
correctement sur `virbr0`, mais une commande `net-start` immédiatement après
répond `already active` — confusion, pas un vrai bug. Voir section
`qemu:///session vs qemu:///system` ci-dessus : c'est presque toujours la
vraie cause derrière ce genre de résultat incohérent.

## Permissions du pool `/home/vms` — VM inaccessibles ou erreurs qemu

**Cause** : ni `adrien` seul ni `qemu` seul ne suffisent — qemu (le process
qui fait tourner les VM) doit pouvoir lire/écrire, et l'utilisateur aussi,
sans sudo à chaque fois.

**Fix** :
```bash
sudo usermod -aG qemu adrien
sudo chown -R adrien:qemu /home/vms
sudo chmod -R 2775 /home/vms   # le bit setgid (2) fait hériter le groupe qemu
                                 # à tout nouveau fichier créé dans ce dossier
```

## cloud-init n'applique pas la config sur un deuxième clone

**Cause** : cloud-init n'exécute sa config qu'une seule fois par
`instance-id`. Si deux VM partagent le même `instance-id` (copier-coller
d'un `meta-data` sans le changer), la deuxième VM ne sera jamais configurée.

**Fix** : `vm-create.sh` génère un `instance-id` unique par VM via
`$(date +%s)-<nom_vm>` — ne jamais réutiliser un `meta-data` d'une VM pour
une autre sans régénérer ce champ.

## `virt-install --boot bios` échoue avec `Unknown --boot options`

**Cause** : `--boot bios` n'est pas une syntaxe valide de `virt-install`.

**Fix** : soit `--boot firmware=bios` (explicite), soit `--boot hd` (ordre de
boot standard — suffisant en pratique, Fedora/KVM démarre déjà en
BIOS/SeaBIOS par défaut sur le chemin `--import` sans qu'il soit nécessaire
de forcer le firmware).

## Makefile qui ignore l'interactivité du script bash sous-jacent

**Symptôme** : `make recreate` (censé demander nom/RAM/vCPUs) se comporte
comme s'il avait toujours reçu des valeurs, sans jamais rien demander.

**Cause** : le Makefile contenait `NAME ?= kali`, `RAM ?= 4096`,
`VCPUS ?= 2` — ces valeurs par défaut sont assignées par Make **avant**
d'appeler le script bash, donc les arguments `$2 $3 $4` ne sont jamais vides
côté bash, et la logique `if [[ -z "$ARG_NAME" ]]` ne se déclenche jamais.

**Fix** : retirer les valeurs par défaut du Makefile, laisser bash gérer
entièrement les défauts et l'interactivité.

## `vagrant up` bloqué / VM fantôme après un prompt sudo expiré

**Symptôme** : `vagrant up` laissé sans surveillance pendant plusieurs
minutes échoue avec `Name '<nom>_default' of domain about to create is
already taken`, même sur un premier essai.

**Cause** : Vagrant a demandé un mot de passe sudo à un moment du
provisioning ; le prompt a expiré faute de réponse, et Vagrant a laissé une
définition libvirt à moitié créée sans nettoyer derrière lui.

**Fix** :
```bash
virsh destroy <nom>_default 2>/dev/null
virsh undefine <nom>_default
rm -rf labs/<nom>   # puis relancer new-ubuntu-lab.sh proprement
```
Éviter de lancer `vagrant up` sans surveiller les premières minutes, au
moins tant que le provisioning ne s'exécute pas encore en tâche de fond.

## Permissions restrictives (600) sur les disques créés par Vagrant

**Symptôme** : `qemu-img info` sur un disque créé par `vagrant up` échoue
avec `Permission denied` en tant qu'utilisateur normal.

**Cause** : vagrant-libvirt ne respecte pas toujours le setgid `2775` posé
sur le pool — le fichier peut être créé avec un umask plus restrictif.

**Fix** : normaliser après coup si besoin :
```bash
sudo chown adrien:qemu /home/vms/<nom>_default.img
sudo chmod 664 /home/vms/<nom>_default.img
```
Note : le *format* du disque reste qcow2 malgré l'extension `.img` — vérifié
via `qemu-img info`, ne pas se fier au nom de fichier pour deviner le format.
