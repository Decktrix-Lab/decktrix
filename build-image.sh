#!/bin/bash

set -e # exit on error
# set -x # debug

readonly TOOLCHAIN_NAME="x86_64-gcc-11.3.0-nolibc-arm-linux-gnueabi.tar.xz"
readonly TOOLCHAIN_EXTRACTED_PATH="gcc-11.3.0-nolibc/arm-linux-gnueabi/bin/arm-linux-gnueabi-"
readonly TFA_DIR="board/tfa/trusted-firmware-a-v2.10.19"
readonly DEBOOTSTRAP_DIR="debootstrap"
readonly DEBOOTSTRAP_PREFETCHED_DIR="debootstrap-prefetched"
readonly KERNEL_DIR="board/linux/linux-v6.17"
readonly UBOOT_DIR="board/u-boot/u-boot-v2025.04"
readonly DEPLOY_DIR="deploy"

readonly STM32_DT="stm32mp157c-dk2.dtb"
readonly STM32_JADARD_DT="stm32mp157c-dk2-jadard.dtb"

prepare_toolchain() {
    echo "-I preparing toolchain for cross compilation"

    mkdir -p toolchain/extracted
    tar -xf $(pwd)/toolchain/${TOOLCHAIN_NAME} -C toolchain/extracted
    CC="$(pwd)/toolchain/extracted/${TOOLCHAIN_EXTRACTED_PATH}"
}

apply_kernel_patches() {
    # The patch may already be applied on the second run which will return error
    # so let's ignore it
    git apply --reject --directory ${KERNEL_DIR} \
        board/linux/patches/0001-defconfig-Add-separate-config-based-on-multi_v7_defc.patch \
        board/linux/patches/0002-dts-Add-separate-device-tree-for-stm32-devboard-with.patch \
        board/linux/patches/0003-display-Add-Jadard-MIPI-driver.patch \
        board/linux/patches/0004-display-Add-Jadard-touch-driver.patch \
        board/linux/patches/0005-dts-Add-support-for-home-button.patch || true
}

build_kernel() {
    echo "-I start kernel build"

    apply_kernel_patches
    make -C ${KERNEL_DIR} ARCH=arm CROSS_COMPILE=${CC} decktrix_defconfig
    make -C ${KERNEL_DIR} ARCH=arm CROSS_COMPILE=${CC} zImage modules dtbs -j$(nproc)
}

apply_uboot_patches() {
    git apply --reject --directory ${UBOOT_DIR} \
        board/u-boot/patches/0001-DT-disable-DSI-node.patch || true
}

build_uboot() {
    echo "-I start u-boot build"

    apply_uboot_patches
    make -C ${UBOOT_DIR} CROSS_COMPILE=${CC} stm32mp15_trusted_defconfig
    make -C ${UBOOT_DIR} CROSS_COMPILE=${CC} DEVICE_TREE=stm32mp157c-dk2 -j all
}

build_tfa() {
    echo "-I start tfa build"

    make -C ${TFA_DIR}  \
        PLAT=stm32mp1 ARCH=aarch32 ARM_ARCH_MAJOR=7 CROSS_COMPILE=${CC} \
        STM32MP_SDMMC=1 STM32MP_EMMC=1 \
        AARCH32_SP=sp_min \
        DTB_FILE_NAME=stm32mp157c-dk2.dtb \
        BL33_CFG=../../u-boot/u-boot-v2025.04/u-boot.dtb \
        BL33=../../u-boot/u-boot-v2025.04/u-boot-nodtb.bin \
        all fip
}

run_in_chroot() {
    sudo chroot ${DEBOOTSTRAP_DIR} /usr/bin/qemu-arm-static /bin/sh -c "$1"
}

mount_vfs() {
    echo "-I mounting proc and sys fs"

    run_in_chroot "mount -t sysfs sysfs /sys"
    run_in_chroot "mount -t proc proc /proc"
}

umount_vfs() {
    echo "-I unmounting proc and sys fs"

    run_in_chroot "umount /sys"
    run_in_chroot "umount /proc"
}

debootstrap() {
    echo "-I starting debootstrap"

    sudo umount ${DEBOOTSTRAP_DIR}/proc ${DEBOOTSTRAP_DIR}/sys || true
    sudo rm -rf ${DEBOOTSTRAP_DIR}

    sudo debootstrap --arch=armhf --foreign trixie ${DEBOOTSTRAP_DIR}
    sudo cp /usr/bin/qemu-arm-static ${DEBOOTSTRAP_DIR}/usr/bin

    run_in_chroot "/debootstrap/debootstrap --second-stage"
}

save_debootstrap_prefetched() {
    sudo rm -rf ${DEBOOTSTRAP_PREFETCHED_DIR}
    sudo cp -r -p ${DEBOOTSTRAP_DIR} ${DEBOOTSTRAP_PREFETCHED_DIR}
}

install_apt_packages() {
    echo "-I installing apt packages"

    run_in_chroot "apt update"

    run_in_chroot "apt install -y \
        sudo \
        ca-certificates \
        systemd-timesyncd \
        openssh-server \
        weston \
        wayland-protocols \
        libwayland-dev \
        sway \
        seatd \
        iwd \
        dbus-user-session \
        resolvconf \
        evtest \
        htop \
        curl \
        gpg \
        libwayland-dev \
        libxkbcommon-dev \
        libevdev-dev \
        cloud-guest-utils \
        chocolate-doom \
        gpiod \
        libffi8 \
        libsdl2-dev \
        libsdl2-image-dev \
        qutebrowser \
        i2c-tools \
        python3-pip \
        python3.13-venv \
    "

}

install_overlays() {
    echo "-I installing files overlays"

    sudo install --verbose --owner=root --group=root --mode=777 \
         overlay/network/etc/resolv.conf ${DEBOOTSTRAP_DIR}/etc/resolv.conf

    sudo install --verbose --owner=root --group=root --mode=664 \
         overlay/sway/usr/lib/systemd/system/sway.service \
         ${DEBOOTSTRAP_DIR}/usr/lib/systemd/system/sway.service

    sudo install --verbose -D --owner=root --group=root --mode=644 \
        overlay/weston/etc/xdg/weston/weston.ini \
        ${DEBOOTSTRAP_DIR}/etc/xdg/weston/weston.ini

    sudo install --verbose -D --owner=root --group=root --mode=644 \
        overlay/weston/usr/lib/systemd/user/weston.service \
        ${DEBOOTSTRAP_DIR}/usr/lib/systemd/user/weston.service

    sudo install --verbose -D --owner=root --group=root --mode=644 \
        overlay/weston/usr/lib/systemd/user/weston.socket \
        ${DEBOOTSTRAP_DIR}/usr/lib/systemd/user/weston.socket

    sudo install --verbose -D --owner=root --group=root --mode=644 \
        overlay/weston/usr/lib/systemd/system/weston-graphical-session.service \
        ${DEBOOTSTRAP_DIR}/usr/lib/systemd/system/weston-graphical-session.service
}

install_opengles_lib() {
    echo "-I install opengles lib"
    sudo install --verbose board/opengles-lib/* ${DEBOOTSTRAP_DIR}/lib || true
}

install_wifi_firmware() {
    echo "-I install wifi firmware"

    sudo install --verbose -D --owner=root --group=root --mode=644 \
        board/wifi-firmware/brcmfmac43430-sdio.txt \
        ${DEBOOTSTRAP_DIR}/lib/firmware/brcm/brcmfmac43430-sdio.st,stm32mp157c-dk2.txt

    sudo install --verbose -D --owner=root --group=root --mode=644 \
        board/wifi-firmware/cyfmac43430-sdio.bin \
        ${DEBOOTSTRAP_DIR}/lib/firmware/brcm/brcmfmac43430-sdio.bin

    sudo install --verbose -D --owner=root --group=root --mode=644 \
        board/wifi-firmware/cyfmac43430-sdio.1DX.clm_blob \
        ${DEBOOTSTRAP_DIR}/lib/firmware/brcm/brcmfmac43430-sdio.clm_blob
}

configure_timesyncd() {
    echo "-I configure timesyncd"
    run_in_chroot "systemctl enable systemd-timesyncd"
}

configure_sshd() {
    echo "-I configure sshd"
    run_in_chroot "sed -i '/#PermitRootLogin prohibit-password/c\PermitRootLogin yes' \
                   /etc/ssh/sshd_config"
}

configure_iwd() {
    echo "-I configure iwd"
    run_in_chroot "sed -i '/#EnableNetworkConfiguration=true/c\EnableNetworkConfiguration=true' \
                   /etc/iwd/main.conf"
    run_in_chroot "systemctl enable iwd"
}

configure_sway() {
    echo "-I configure sway"
    run_in_chroot "systemctl enable sway"
}

setup_root_user() {
    echo "-I setup root user"
    run_in_chroot "echo \"root:root\" | chpasswd"
}

setup_debian_user() {
    echo "-I setup debian user"
    run_in_chroot "useradd -G sudo,video,render,input -m debian"
    run_in_chroot "echo \"debian:temp\" | chpasswd"
    run_in_chroot "chsh -s /bin/bash debian"
}

setup_hostname() {
    echo "-I setup hostname"
    run_in_chroot "echo debian-stm32 > /etc/hostname"
    run_in_chroot "echo 127.0.0.1 debian-stm32 >> /etc/hosts"
}

setup_fstab() {
    echo "-I setup fstab"
    run_in_chroot "echo \"/dev/mmcblk0p4  /  auto  errors=remount-ro  0  1\" > /etc/fstab"
}

setup_extlinux() {
    echo "-I setup extlinux"

    selected_dt=${1}
    KERNEL_VERSION=$(cat "${KERNEL_DIR}/include/generated/utsrelease.h" | awk '{print $3}' | sed 's/\"//g' )

    run_in_chroot "mkdir -p /boot/extlinux/"
    run_in_chroot "echo 'label Linux ${KERNEL_VERSION}' > /boot/extlinux/extlinux.conf"
    run_in_chroot "echo '    kernel /boot/vmlinuz-${KERNEL_VERSION}' >> /boot/extlinux/extlinux.conf"
    run_in_chroot "echo '    fdt  /boot/dtbs/${KERNEL_VERSION}/${selected_dt}' >> /boot/extlinux/extlinux.conf"
    run_in_chroot "echo '    append console=ttySTM0,115200 root=/dev/mmcblk0p4 ro rootfstype=ext4 rootwait earlycon net.ifnames=0' \
                    >> /boot/extlinux/extlinux.conf"
}

install_kernel_image() {
    echo "-I install kernel image"
    sudo install --verbose --owner=root --group=root --mode=644 \
        ${KERNEL_DIR}/arch/arm/boot/zImage ${DEBOOTSTRAP_DIR}/boot/vmlinuz-${KERNEL_VERSION}
}

install_kernel_modules() {
    echo "-I install kernel modules"
    sudo make -C ${KERNEL_DIR} ARCH=arm CROSS_COMPILE=${CC} modules_install \
        INSTALL_MOD_PATH="../../../${DEBOOTSTRAP_DIR}/usr"
}

install_device_tree() {
    echo "-I install device tree"
    run_in_chroot "mkdir -p boot/dtbs/${KERNEL_VERSION}"
    sudo make -C ${KERNEL_DIR} ARCH=arm CROSS_COMPILE=${CC} dtbs_install \
        INSTALL_DTBS_PATH="../../../${DEBOOTSTRAP_DIR}/boot/dtbs/${KERNEL_VERSION}"
}

install_tfa() {
    echo "-I install TFA"
    cp ${TFA_DIR}/build/stm32mp1/release/tf-a-stm32mp157c-dk2.stm32 \
       ${TFA_DIR}/build/stm32mp1/release/fip.bin ${DEPLOY_DIR}
}

enable_serial_console() {
    echo "-I enable serial console"
    run_in_chroot "systemctl enable serial-getty@ttyS0.service"
}

use_prefetched_download() {
    echo "-I use prefetch folder"

    if [ ! -d "${DEBOOTSTRAP_PREFETCHED_DIR}" ]; then
        echo "-E Directory '${DEBOOTSTRAP_PREFETCHED_DIR}' doesn't exists"
        echo "Run this script with '-p|--prefetch-debootstrap' option first"
        exit 1
    fi
    sudo umount ${DEBOOTSTRAP_DIR}/proc ${DEBOOTSTRAP_DIR}/sys || true
    sudo rm -rf ${DEBOOTSTRAP_DIR}
    sudo cp -p -r ${DEBOOTSTRAP_PREFETCHED_DIR} ${DEBOOTSTRAP_DIR}
}

create_rootfs_ext4() {
    sudo rm -rf ${DEPLOY_DIR} && mkdir -p ${DEPLOY_DIR}
    sudo dd if=/dev/zero of=${DEPLOY_DIR}/rootfs.ext4 bs=1 count=0 seek=2500M
    sudo mkfs.ext4 -F ${DEPLOY_DIR}/rootfs.ext4 -d ${DEBOOTSTRAP_DIR}
}

generate_sdcard_img() {
    echo "-I generate sdcard image"
    genimage --inputpath deploy --outputpath deploy --config genimage.cfg
}

print_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "This script will build the SD card image for STM32 Linux kit"
    echo ""
    echo "On first run do:"
    echo "    $0 --prefetch-debootstrap"
    echo ""
    echo "This will store the debian download files in cache"
    echo "And will run apt install with custom packages"
    echo ""
    echo "And then to use this cache do:"
    echo "    $0 --use-prefetch"
    echo ""
    echo "Options:"
    echo "    -h, --help    show this help message and exit"
    echo "    -p, --prefetch-debootstrap    downloads debian and saves the result"
    echo "    -u, --use-prefetch-debootstrap    use cached download folder"
    echo "    -s, --skip    skip tfa, u-boot and kernel builds"
    echo "    -v, --variant [stm32, stm32-jadard]    select device variant"
}

start_image_build() {
    skip_board=false
    selected_dt=${STM32_DT}

    POSITIONAL_ARGS=()

    while [[ $# -gt 0 ]]; do
      case $1 in
        -p|--prefetch-debootstrap)
          prefetch_debootstrap=true
          shift
          ;;
        -u|--use-prefetch-debootstrap)
          use_prefetched_debootstrap=true
          shift
          ;;
        -s|--skip)
          skip_board=true
          shift
          ;;
        -v|--variant)
            if [ "$2" = "stm32" ]; then
                selected_dt=${STM32_DT}
            elif [ "$2" = "stm32-jadard" ]; then
                selected_dt=${STM32_JADARD_DT}
            else
                echo "Invalid selected variant, valid are: [stm32, stm32-jadard]"
                exit 1
            fi
            shift
            shift # argument
            ;;
        -h|--help)
          print_help
          exit 0
          ;;
        -*|--*)
          echo "Unknown option $1"
          exit 1
          ;;
        *)
          POSITIONAL_ARGS+=("$1") # save positional arg
          shift # past argument
          ;;
      esac
    done

    set -- "${POSITIONAL_ARGS[@]}"

    prepare_toolchain

    if [ "${skip_board}" = false ] ; then
        build_kernel
        build_uboot
        build_tfa
    fi

    # Prefetch debootstrap and install apt packages
    if [ "${prefetch_debootstrap}" = true ] ; then
        debootstrap
        mount_vfs
        install_apt_packages
        umount_vfs
        save_debootstrap_prefetched
        exit 0
    fi

    if [ "${use_prefetched_debootstrap}" = true ] ; then
        use_prefetched_download
    else
        debootstrap
    fi

    mount_vfs

    # If '--use-prefetch-debootstrap' option is used we may still want
    # to install additional packages on the next runs
    install_apt_packages

    install_overlays
    install_opengles_lib
    install_wifi_firmware

    configure_timesyncd
    configure_sshd
    configure_iwd
    configure_sway

    setup_root_user
    setup_debian_user
    setup_hostname
    setup_fstab
    setup_extlinux ${selected_dt}

    install_kernel_image
    install_kernel_modules
    install_device_tree

    enable_serial_console

    umount_vfs

    create_rootfs_ext4

    # TFA should be installed after deploy dir is recreated
    install_tfa

    generate_sdcard_img
}

start_image_build "$@"
