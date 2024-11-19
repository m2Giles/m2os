# m2Giles' OS

[![Build m2os](https://github.com/m2Giles/m2os/actions/workflows/build.yml/badge.svg)](https://github.com/m2Giles/m2os/actions/workflows/build.yml)

These are my customized versions of universal blue images for my needs. Everything is a tag off of m2os.

Bazzite is gnome version. Bazzite Desktop version includes nvidia drivers. ISOs are built for aurora/bazzite/bluefin/cosmic and are artifacts.

Note, this is also a place I use to experiment before making changes in Universal Blue.

Occaisionally, I will build beta versions around Fedora Major Release time.

## Tags

### Desktop Images
These images are aimed for desktop use. All of them are based on Bluefin's stable-daily.

Aurora is built from Aurora, Bluefin from Bluefin, and Cosmic from base-main.

All images have zfs support. Nvidia Images have nvidia included as well.

These add in the following: Docker, Incus, and Steam plus different editors. A reasonable way to think of these images as -dx images without virt-manager plus steam/lutris.

- aurora
- aurora-nvidia
- bluefin
- bluefin-nvidia
- cosmic
- cosmic-nvidia

### Bazzite Images
These images are based on Bazzite's Gnome images. `bazzite` is based on gnome-nvidia and `bazzite-deck` is based on gnome deck image.

These include several -dx like items like multiple editors, docker, and incus.

- bazzite
- bazzite-deck

### Ucore Images
These images are based on the `ucore:zfs` images. They mostly just add Docker from Docker instead of using moby-engine and incus.

- ucore
- ucore-nvidia


## How to Install

### Desktop/Bazzite Images
ISO's for Desktop and Bazzite Images are built using an action and uploaded as an artifact. The artifacts are linked in the releases for download. They are zipped. The ISO uses the Kinoite version meaning that you will need to create a user in Anaconda. Each release has a changelog with links to the ISOs.

For the Latest ISOs:
https://github.com/m2giles/m2os/releases/latest

Note artifacts are removed after 90 days though ISOs are refreshed weekly.

### Ucore
Use the coreos installer and in the ignition file switch to one of these images.

### Rebasing
You can rebase to an **m2os** image using the following:
```console
$ sudo bootc switch --enforce-container-sigpolicy ghcr.io/m2giles/m2os:TAG
```
Replace TAG with the specified image. This is also the method for switching to Ucore.


## Verification
All images in this repo are signed with sigstore's cosign. You can verify the signatures by running the following command
```console
$ cosign verify --key "https://raw.githubusercontent.com/m2Giles/m2os/refs/heads/main/cosign.pub" "ghcr.io/m2giles/m2os:TAG
```
Again replace the TAG with the specified image

## DIY
This repo was build on the [Universal Blue Image Template](https://github.com/ublue-os/image-template) and added to significantly.

It is possible to build all images and ISOs locally using the provided `Justfile` with `just`. For example to build `m2os:bluefin` just do:

```console
$ just build bluefin
```
