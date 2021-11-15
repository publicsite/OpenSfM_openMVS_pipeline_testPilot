#!/bin/sh
wget http://cdimage.ubuntu.com/ubuntu-base/releases/20.04.2/release/ubuntu-base-20.04.1-base-amd64.tar.gz
mkdir rootfs
sudo tar -xf ubuntu-base-20.04.1-base-amd64.tar.gz -C rootfs
sudo cp -a /etc/resolv.conf rootfs/etc/

mkdir rootfs/source
chmod a+x install.sh
cp install.sh rootfs/
chmod a+x install2.sh
cp install2.sh rootfs/
chmod a+x install3.sh
cp install3.sh rootfs/
cp -a patches rootfs/source

sudo chroot rootfs mknod /dev/null c 1 3
sudo chroot rootfs chmod 666 /dev/null

sudo chroot rootfs /install.sh
sudo chroot rootfs /install2.sh

sudo cp -a makeSubmodelStructure.sh rootfs/source/OpenSfM/
sudo cp -a runRest.sh rootfs/source/OpenSfM/

#sudo rm rootfs/etc/resolv.conf
