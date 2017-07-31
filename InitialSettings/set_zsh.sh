#!/bin/bash

cur_path=$(pwd)

apt-get install zsh nodejs

chsh -s /usr/bin/zsh

cd /tmp
curl -L https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh | sh
svn co https://github.com/caiogondim/bullet-train.zsh.git
cd bullet-train.zsh.git/trunk
cp bullet-train.zsh-theme $ZSH/.oh-my-zsh/themes/

#TODO russel.. -> bullet-train

ln -s /usr/src/nodejs node

git clone https://github.com/powerline/fonts
cd fonts
./install.sh

cd $cur_path
