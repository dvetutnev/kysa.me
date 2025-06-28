---
title: NixOS on Raspberry Pi4
author: Dmitriy Vetutnev
date: July 2022
---


![](nixos-hires.png)

Установка NixOS на малинку.

[Основная статья](https://nixos.wiki/wiki/NixOS_on_ARM/Raspberry_Pi_4)

Для упрощения все операции выполняются под *root* `sudo -i`.

# UART console

Для того, чтобы работала UART-консоль исправляем командную строку ядра в файле (на SD-карте с развернутым образом) `boot/extlinux/extlinux.conf`, вставляем настройки `8250.nr_uarts=1 console=ttyS0,115200 console=tty0 loglevel=7`. Общий вид файла:
```sh
[root@nixos: ~root@nixos:~]# cat /boot/extlinux/extlinux.conf 
# Generated file, all changes will be lost on nixos-rebuild!

# Change this to e.g. nixos-42 to temporarily boot to an older configuration.
DEFAULT nixos-default

MENU TITLE ------------------------------------------------------------
TIMEOUT 50

LABEL nixos-default
  MENU LABEL NixOS - Default
  LINUX ../nixos/i9qrfl182zghy44idhr2i7pk19806wzp-linux-5.15.50-Image
  INITRD ../nixos/vhczxaiaqjbmdq12sxac6f2mg8xmsh4g-initrd-linux-5.15.50-initrd
  APPEND init=/nix/store/h96p25jfcf0h3k08az0a4caa83lvk5mc-nixos-system-nixos-22.05.1460.9e96b1562d6/init 8250.nr_uarts=1 console=ttyS0,115200 console=tty0 loglevel=7
  FDTDIR ../nixos/i9qrfl182zghy44idhr2i7pk19806wzp-linux-5.15.50-dtbs
```

# Первоначальное подключение к Wi-Fi

```sh
[root@nixos: ~root@nixos:~]# wpa_supplicant -B -i wlan0 -c <(wpa_passphrase 'ssid' 'password') &
[root@nixos: ~root@nixos:~]# ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
    link/ether e4:5f:01:0b:3d:84 brd ff:ff:ff:ff:ff:ff
3: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether e4:5f:01:0b:3d:85 brd ff:ff:ff:ff:ff:ff
    inet 192.168.1.200/24 brd 192.168.1.255 scope global noprefixroute wlan0
       valid_lft forever preferred_lft forever
    inet6 fe80::e65f:1ff:fe0b:3d85/64 scope link 
       valid_lft forever preferred_lft forever
```

Устанавливаем пароль
```sh
[root@nixos: ~root@nixos:~]# passwd nixos
```

Подключаемся через SSH

```sh
dvetutnev@vulpecula:~$ ssh -o IdentitiesOnly=yes nixos@192.168.1.200
```

# Update firmware
```sh
[root@nixos: ~root@nixos:~]# nix-shell -p raspberrypi-eeprom
[nix-shell:~]# mount /dev/disk/by-label/FIRMWARE /mnt
[nix-shell:~]# BOOTFS=/mnt FIRMWARE_RELEASE_STATUS=stable rpi-eeprom-update -d -a
BOOTLOADER: up to date
   CURRENT: Tue Apr 26 10:24:28 AM UTC 2022 (1650968668)
    LATEST: Thu Mar 10 11:57:12 AM UTC 2022 (1646913432)
   RELEASE: stable (/nix/store/kwwrz1iajjl0g004yd9iv4a3iklxsql8-raspberrypi-eeprom-unstable-2022-03-10/share/rpi-eeprom/stable)
            Use raspi-config to change the release.

  VL805_FW: Using bootloader EEPROM
     VL805: up to date
   CURRENT: 000138a1
    LATEST: 000138a1
```

У меня прошивка платы была обновленна раньше при официального [образа SD-карты](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#updating-the-bootloader).

# Install NixOS
Генерируем и правим конфиг
```sh
[root@nixos:~]# nixos-generate-config
[root@nixos:~]# nano /etc/nixos/configuration.nix
```

На текущий момент (22.05) сломана интеграция Nix и загрузчика raspberryPi, поэтому используется U-Boot с интеграцией через файл `/boot/extlinux/extlinux/conf`.
```nix
{ config, pkgs, lib, ... }:

{
  imports =
    [
      <nixos-hardware/raspberry-pi/4>
      ./hardware-configuration.nix
    ];

  boot = {
    kernelPackages = pkgs.linuxPackages_rpi4;
    tmpOnTmpfs = true;
    initrd.availableKernelModules = [ "xhci_pci" "usbhid" "usb_storage" ];
    kernelParams = [ "8250.nr_uarts=1" "console=ttyS0,115200" "console=tty0" ];
    consoleLogLevel = 6;
    loader = {
      raspberryPi.enable = false;
      raspberryPi.version = 4;
      grub.enable = false; 
      generic-extlinux-compatible.enable = true;
    };
  };

  hardware.enableRedistributableFirmware = true;

  networking = {
    hostName = "pyxis";
    networkmanager.enable = true;
  };

  time.timeZone = "Europe/Moscow";

  users.mutableUsers = false;
  users.users.user = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ]; # Enable ‘sudo’ for the user.
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJoR7Cwxg7R16Z5EalwqfKN+14mKPSVPNx7APxQpDy9V dvetutnev@vulpecula" ];
    hashedPassword = "$6$6mhSHsbqHTo70YZW$XXtL1h8WbJBuWsxI9V1wrTUBj7UcoF/5c7GCQTZPC/c4teJGKolcaM9lL8F0YMUaExC6f4BEaXwDWBtMpr7AM0";
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    networkmanager
    vim
    wget
  ];

  environment.variables = {
    EDITOR = "vim";
  };

  services.openssh = {
    enable = true;
    passwordAuthentication = false; # default true
    permitRootLogin = "yes";
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  nix = {
    autoOptimiseStore = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    # Free up to 1GiB whenever there is less than 100MiB left.
    extraOptions = ''
      min-free = ${toString (100 * 1024 * 1024)}
      max-free = ${toString (1024 * 1024 * 1024)}
    '';
  };

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.05"; # Did you read the comment?
}
```

Значение для [`users.users.<name>.hashedPassword`](https://nixos.org/manual/nixos/stable/options.html#opt-users.users._name_.hashedPassword) таким образом:
```sh
[root@nixos:~]# nix-shell -p mkpasswd
[nix-shell:~]$ mkpasswd -m sha-512
Password:
```

Добавляем канал **nixos-hardware**
```sh
[root@nixos:~]# nix-channel --add https://github.com/NixOS/nixos-hardware/archive/master.tar.gz) nixos-hardware
```

Для образов SD-карточек на текущий момент рекомендованый способ инсталяции это генерация новой кофигурации (а не выполнение `nixos-install`)
```sh
[root@nixos:~]# nix-channel --update
[root@nixos:~]# nixos-rebuild switch
[root@nixos:~]# reboot
```

# Setup Wi-Fi
Смотрим список сетей и подключаемся к своей
```sh
[user@pyxis:~]$ nmcli dev wifi list
IN-USE  BSSID              SSID            MODE   CHAN  RATE        SIGNAL  BAR>
*       E8:DA:34:C2:F1:5E  mywifi          Infra  2     270 Mbit/s  72 ▂▄▆>
        18:0F:76:AD:A6:75  DIR-615T        Infra  9     270 Mbit/s  69 ▂▄▆>
        B0:95:75:76:75:DB  TP-Link_75DB    Infra  4     270 Mbit/s  52 ▂▄_>
        E8:94:F6:B6:AC:5A  TP-LINK_B6AC5A  Infra  11    270 Mbit/s  50 ▂▄_>
q

[user@pyxis:~]$ nmcli dev wifi connect mywifi password "password"
```
