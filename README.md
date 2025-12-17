# Build steps

1. Init submodules

```
git submodule update --init --recursive --depth 1
```

2. Prefetch debootstrap on first run to speed next iterations

```
sudo ./build-image.sh --prefetch-debootstrap
```

3. Build SD card image

```
sudo ./build-image.sh --use-prefetch-debootstrap
```

4. Write image to SD card

```
sudo dd if=deploy/sdcard.img of=<sd-card-dev> bs=8M conv=fdatasync status=progress
```

## Docker (WIP)

1. Build docker container

```
docker build -t decktrix .
```

2. Run docker container and login to shell

```
docker run -it --volume /etc/passwd:/etc/passwd:ro \
               --volume /etc/group:/etc/group:ro \
               --volume /etc/shadow:/etc/shadow:ro \
               --volume .:/home/${USER} \
               --user $(id -u) \
               decktrix bash
```

## Wifi
Connect to WiFi - [instructions](https://wiki.archlinux.org/title/Iwd)

## Setup ip on eth0

```
sudo ip addr add 192.168.0.2/24 dev eth0
sudo ip link set dev eth0 up
```

## Resize FS

```
sudo growpart /dev/mmcblk0 4
sudo resize2fs /dev/mmcblk0p4
df -h
```

## Bluetooth

```
sudo apt install bluez bluez-tools
bluetoothctl
power on  # in case the bluez controller power is off
agent on
scan on  # wait for your device's address to show up here
scan off
trust MAC_ADDRESS
pair MAC_ADDRRESS
connect MAC_ADDRESS
```

## Packages for cross compilation

```
sudo apt install g++-arm-linux-gnueabihf
sudo apt install gcc-arm-linux-gnueabihf
```

## Rotate screen on sway

```
export SWAYSOCK=/home/debian/sway-ipc.$(id -u).$(pgrep -x sway).sock

# horizontal orientation
swaymsg output DSI-1 transform 90

# vertical orientation
swaymsg output DSI-1 transform 0
```

## Run launcher

```
export SWAYSOCK=/home/debian/sway-ipc.$(id -u).$(pgrep -x sway).sock
swaymsg "exec /usr/bin/launcher -l -E /dev/input/by-path/platform-gpio-keys-event -A /etc/apps.toml"
```

## Toggle sway bar

```
export SWAYSOCK=/home/debian/sway-ipc.$(id -u).$(pgrep -x sway).sock
swaymsg bar mode toggle
```

## Setup Ethernet over USB and enable internet sharing from PC

Load usb gadget driver on target

```
sudo modprobe g_ether
sudo ip link set usb0 up
```

On host network GUI change new usb interface IPv4 method to
"Share to other computers" it will assign ip addr automatically

Setup ip address on target based on host's ip:

```
sudo ip addr add 10.42.0.10/24 dev usb0
```

Add routing host ip to routing table

```
sudo ip route add default via 10.42.0.1 dev usb0
```

Enable packet forwarding

```
sudo sysctl -w net.ipv4.ip_forward=1
```

On target test internet connection

```
ping google.com
```

## Install gstreamer for playing video

```
sudo apt-get install gstreamer1.0-tools gstreamer1.0-plugins-base \
                     gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
                     gstreamer1.0-plugins-ugly gstreamer1.0-libav
```

# References

[1] https://forum.digikey.com/t/debian-getting-started-with-the-stm32mp157/12459 <br>
[2] https://github.com/cvetaevvitaliy/stm32mp1-ubuntu <br>
[3] https://linux-sunxi.org/Debootstrap <br>
