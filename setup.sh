##Install Debian to sd card on made_change## https://www.raspberrypi.org/documentation/installation/installing-images/mac.md

##functions used below
##https://github.com/asb/raspi-config/blob/master/raspi-config#L118
set_config_var() {
  lua - "$1" "$2" "$3" <<EOF > "$3.bak"
local key=assert(arg[1])
local value=assert(arg[2])
local fn=assert(arg[3])
local file=assert(io.open(fn))
local made_change=false
for line in file:lines() do
  if line:match("^#?%s*"..key.."=.*$") then
    line=key.."="..value
    made_change=true
  end
  print(line)
end
if not made_change then
  print(key.."="..value)
end
EOF
mv "$3.bak" "$3"
}

get_config_var() {
  lua - "$1" "$2" <<EOF
local key=assert(arg[1])
local fn=assert(arg[2])
local file=assert(io.open(fn))
for line in file:lines() do
  local val = line:match("^#?%s*"..key.."=(.*)$")
  if (val ~= nil) then
    print(val)
    break
  end
end
EOF
}


##update the pi
apt-get -y update
apt-get -y upgrade
cd ~
apt-get -y install htop curl git

##config pi
##https://github.com/asb/raspi-config/blob/master/raspi-config

##update hostname
##make sure to update this with the correct hostname
hostname office.home.davidplappert.com

##enable ssh
update-rc.d ssh enable
update-rc.d ssh start

##enable camera
CONFIG=/boot/config.txt
set_config_var start_x 1 $CONFIG
CUR_GPU_MEM=$(get_config_var gpu_mem $CONFIG)
if [ -z "$CUR_GPU_MEM" ] || [ "$CUR_GPU_MEM" -lt 128 ]; then
  set_config_var gpu_mem 128 $CONFIG
fi
sed $CONFIG -i -e "s/^startx/#startx/"
sed $CONFIG -i -e "s/^fixup_file/#fixup_file/"

##force audio out 3.5mm port
amixer cset numid=3 1

##fix time
dpkg-reconfigure locales
dpkg-reconfigure tzdata

##video setup
## http://www.linux-projects.org/uv4l/installation/
curl http://www.linux-projects.org/listing/uv4l_repo/lrkey.asc | sudo apt-key add -
echo "deb http://www.linux-projects.org/listing/uv4l_repo/raspbian/ jessie main" >>  /etc/apt/sources.list
apt-get -y update
apt-get -y install uv4l uv4l-raspicam uv4l-raspicam-extras uv4l-server uv4l-uvc uv4l-xscreen uv4l-mjpegstream uv4l-dummy uv4l-raspidisp uv4l-webrtc uv4l-xmpp-bridge
cp /root/raspi-ha/setup_files/uv4l-raspicam.conf /etc/uv4l/uv4l-raspicam.conf
chmod 555 /etc/uv4l/uv4l-raspicam.conf
service uv4l_raspicam restart

## audio setup
## http://www.redsilico.com/multiroom-audio-raspberry-pi
apt-get -y install build-essential git autoconf automake libtool libdaemon-dev libasound2-dev libpopt-dev libconfig-dev avahi-daemon libavahi-client-dev libssl-dev libpolarssl-dev libsoxr-dev
git clone https://github.com/mikebrady/shairport-sync.git
cd shairport-sync
autoreconf -i -f
./configure --sysconfdir=/etc --with-alsa --with-avahi --with-ssl=openssl --with-metadata --with-soxr --with-systemd
make
getent group shairport-sync &>/dev/null || sudo groupadd -r shairport-sync >/dev/null
getent passwd shairport-sync &> /dev/null || sudo useradd -r -M -g shairport-sync -s /usr/bin/nologin -G audio shairport-sync >/dev/null
make install
systemctl enable shairport-sync
cp /root/raspi-ha/setup_files/shairport-sync.conf /etc/shairport-sync.conf

##setup new user, and remove pi user
useradd davidplappert
mkdir -p /home/davidplappert/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0tRFmXA0/w1tJZa1EpU1oGKFsN2VM0wuoSjUber7ZjDlwy5/R620H0mZ8cfx2Wdbe0alSN2qpSfnr7v89ttkN9G9827H+asH6OFOqB6v3AjVlUkIc1vfmY9jccu+lXy6CF7ML2d++XtBPJajQD4m8HL4usZx82G5+NjYLi3A+Vj0jDeVmcRAZZoOt2BUqDFXc9xzUOWbdi2WKya3kB5nScdyijmW19YfrGtSg+T8uoSXzCnFpeuzXdnSktJN+XhUmj9moAUylHqREqmomN1A1eo2aGjvzohBD41dQXA7CzteKnaS6OKa7E1Dj/51TZwFRFJSkWgW+TbcQVuFD1/jB daplappert@ucstreaming.net" > /home/davidplappert/.ssh/authorized_keys
chown -R davidplappert /home/davidplappert
sed -i -e 's/pi/davidplappert/g' /etc/sudoers.d/010_pi-nopasswd

cp /root/raspi-ha/setup_files/profile /home/davidplappert/.profile
chmod 755 /home/davidplappert/.profile

userdel pi
rm -rf /home/pi

cp /root/raspi-ha/setup_files/bashrc /root/.bashrc
chmod 755 /root/.bashrc

reboot
