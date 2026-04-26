#!/bin/sh
passwd root
apt update
apt upgrade -y
apt install zsh git curl locales-all task-chinese-s -y
timedatectl set-timezone Asia/Shanghai
update-locale LANG=zh_CN.UTF-8 LANGUAGE=zh_CN.UTF-8
mkdir ~/.ssh
chmod 700 ~/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCe++kanJ7RJeixuP/u7ZyWTrrPl6L6BWVKFNqz19QXstCFS+1sD2bNOU+S5u4Y6oPbobw3FPHeFBL3BrjYxJ009FF2sBI7FdZlfNgJWoP44w/KGwxVKdm6nssgMKj0Qfz8uE8wCBBG3GX55+i7sLOBD6hTeD0B7//nsRHw/3H6U32XaEaVh1QMAHMnY0/dEXbc7Ne1ftabQ0IrJ76KCstsGBNoFsRHZkBw+1s+NFjLlGAM05bDJVlfsegTP+HwJQCdiVo1y+JSP/sKYbKfUarEZRlgVyHI4AXsdsDF8u/tgJCAcbS+G/Jlj0l+iFXnz7T+EfzsNy7pHzRxOQtTGLeAD1OhGWcv2aXs4sDdGG0UlLXWwgop1kBuMkKOC6hDI0L7ybjWz8BfWtIhi3fZiESvgowmjXc7MIGcjO2Q8E7TGgGeIIq0NaJRBI2j9NZpr7vFEOSpx35ddOZxaEqwwggsdE24vzbZi1ZQEulxmQwFD9bqodsCWRYMjdcu3XuXY9k= stiffyfoto@gmail.com" > ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo -e "PasswordAuthentication yes\nPubkeyAuthentication yes" >> /etc/ssh/sshd_config
rm -fr /usr/local/man
wget "https://raw.githubusercontent.com/stiffyfoto/mystash/refs/heads/main/Xray-TLS-Web-setup.sh"
chmod 755 Xray-TLS-Web-setup.sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
echo 'alias ls="ls -alFh --color"' >> ~/.zshrc
echo 'setopt nonomatch' >> ~/.zshrc
sed -i 's/robbyrussell/ys/g' ~/.zshrc
source ~/.zshrc
# abc3cd44-53b5-4e8e-a9aa-36369132d596 
# apt install ufw -y 
# ufw allow 22
# ufw allow 80
# ufw allow 443
# ufw allow 16384
# ufw allow 16888
# ufw enable
# ufw status