#!/bin/bash

# Uninstall existing Hailo SW

HAILO_PACKAGES=("hailo10h-driver-fw" "hailort-pcie-driver" "hailort")

for pkg in "${HAILO_PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $pkg "; then
        echo "-I- Uninstalling $pkg"
        sudo apt-get remove --purge -y "$pkg"
    else
        echo "-I- $pkg not installed"
    fi
done


#Install Hailo-10 Driver

#Deps to build and install kernel module
sudo apt-get install curl build-essential dkms pciutils -y

curl -fsSLO https://storage.googleapis.com/deepperception_public/hailo/h10/hailo10h-driver-fw_5.0.0_all.deb

yes | sudo dpkg -i hailo10h-driver-fw_5.0.0_all.deb

#Install HailoRT

curl -fsSLO https://storage.googleapis.com/deepperception_public/hailo/h10/hailort_5.0.0_amd64.deb

echo "" | sudo DEBIAN_FRONTEND=noninteractive dpkg -i --force-confdef hailort_5.0.0_amd64.deb

#Download model for test

curl -fsSLO https://storage.googleapis.com/deepperception_public/hailo/h10/h10_yolox_l_leaky.hef

#Reboot

echo "Rebooting System to complete install"
sudo shutdown -r now
