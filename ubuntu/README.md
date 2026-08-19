# Ubuntu (via Vagrant + box custom)

Contrairement à Debian (template cloud générique + clone COW maison), Ubuntu
utilise une box Vagrant custom : `dfir-ubuntu-base`, construite avec Packer.

## Où vit quoi

- **Ce dossier** : Vagrantfile minimal + scripts pour enregistrer la box et
  créer des labs. C'est tout ce qu'il faut pour *utiliser* la box.
- **Le template Packer** (`.pkr.hcl`) qui *construit* la box vit dans un
  **autre dépôt**, lié à un projet spécifique (pas dupliqué ici). Voir
  `<url-du-depot-packer>` si besoin de le retrouver.
- **La box construite** (`dfir-ubuntu-base.box`, ~4-5G) est sauvegardée sur
  un drive externe. C'est le seul artefact nécessaire pour ce dépôt-ci —
  pas besoin de Packer pour simplement lancer des VM Ubuntu.

## Utilisation

```bash
# Une fois (par machine hôte)
./install-vagrant.sh
./setup-box.sh /chemin/vers/drive/dfir-ubuntu-base.box

# Pour chaque nouveau lab
./new-ubuntu-lab.sh monlab 4096 4
```

Chaque lab vit dans son propre dossier sous `labs/<nom>/` avec son propre
état Vagrant (`.vagrant/`) — plusieurs VM Ubuntu peuvent coexister sans se
marcher dessus.

## Ajouter du provisioning spécifique à un projet

Le `Vagrantfile` généré dans chaque `labs/<nom>/` est une copie indépendante
du template. Pour un besoin spécifique (comme un poste DFIR avec Wireshark,
Volatility3, Autopsy...), éditer directement le `Vagrantfile` du lab
concerné — ça n'affecte ni le template, ni les autres labs.

## Si la box du drive est perdue

1. Retrouver le dépôt Packer (`<url-du-depot-packer>`)
2. Suivre son README pour `packer build` + `vagrant box add` (ou utiliser
   `box.sh` s'il est présent dans ce dépôt Packer)
3. Une fois la nouvelle `.box` produite, relancer `./setup-box.sh` depuis ici
