#!/bin/sh
echo "----------------更新系统---------------"
sudo apt-get update
sudo apt-get upgrade
echo "----------------安装ZSH、git、wget-----"
sudo apt-get install zsh git wget
echo "----------------安装oh-my-zsh----------"
sh -c "$(wget https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"
echo "----------------安装zsh插件------------"
# syntax-highlighting
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
# autosuggestions
git clone git://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
echo "----------------拉取线上的.zshrc-------"
wget url -O .zshrc