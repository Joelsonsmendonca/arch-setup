# arch-setup

Infra pessoal em Arch Linux — mantém **PC e notebook idênticos e atualizados**
("tipo Windows Update") e gera uma **ISO** de reinstalação. Tudo hospedado de
graça no GitHub (Actions + Pages + Releases).

## Como funciona

```
                    ┌─────────────────────── GitHub (grátis) ──────────────────────┐
  edito PKGBUILD    │  Actions: compila + assina (GPG) os pacotes                  │
  e dou push  ───▶  │           publica no GitHub Pages  ──▶  repo pacman [joelson] │
                    │  Actions: mensal, monta a ISO  ──▶  GitHub Releases           │
                    └─────────────────────────────────────────────────────────────┘
                                          │
                        pacman -Syu       │       pacman -Syu
                     ┌────────────────────┴────────────────────┐
                    PC                                       notebook
```

- **`packages/joelson-base/PKGBUILD`** — meta-pacote: o array `depends` é a lista
  única de "o que tem que estar instalado". Editou, deu bump em `pkgrel`, `push` →
  o CI recompila/assina/publica → `pacman -Syu` nos dois PCs traz a mudança.
- **`packages/joelson-nvidia/`** — parte específica de NVIDIA (instala junto).
- **`aur/list.txt`** — pacotes do AUR que o CI compila e serve no meu repo
  (assim `pacman` resolve tudo sem `yay`/`paru` nas máquinas).
- **`iso/`** — customização do profile `releng` do archiso: injeta `[joelson]` +
  `multilib` no `pacman.conf` e adiciona `iso/airootfs/root/install.sh` (wrapper do
  **archinstall** com `joelson.json` já preenchido).
- **`postinstall.sh`** — publicado no Pages; um comando que põe qualquer máquina no
  trilho (repo + `joelson-base` + serviços + dotfiles). Fase 2 da instalação e
  também o "passo B" pra PCs que já rodam Arch.
- **`repo/`** — chave pública GPG (`joelson-repo.gpg`) e `KEYID`. A **chave
  privada** vive só no secret `GPG_PRIVATE_KEY` do repo, nunca é commitada.
- Dotfiles ficam em outro repo: **[hyprdots](https://github.com/Joelsonsmendonca/hyprdots)**.

## Primeira configuração

- Máquina que já roda Arch: [`SETUP.md`](SETUP.md) (passo B).
- Máquina **sem sistema** (instalar do zero pela ISO): [`INSTALL.md`](INSTALL.md).

## Adicionar / remover um app

1. edita `depends` em `packages/joelson-base/PKGBUILD`
2. `pkgrel=$((pkgrel+1))` (ou bump `pkgver`)
3. `git commit && git push`
4. espera o workflow **repo** ficar verde (~3-5 min)
5. nos dois PCs: `sudo pacman -Syu`

Pacote do AUR novo: adiciona o nome em `aur/list.txt` e referencia em `depends`.

## Regenerar a ISO

Actions → workflow **iso** → *Run workflow*. Sai em Releases como `latest`.
