#!/bin/bash
rm -rf $HOME/.dots
git clone --separate-git-dir=$HOME/.dots https://github.com/XelK/dots.git /tmp/dots
rsync --recursive --verbose --exclude '.git' /tmp/dots/ $HOME/
rm -rf /tmp/dots
/usr/bin/git --git-dir=$HOME/.dots/ --work-tree=$HOME config --local status.showUntrackedFiles no
/usr/bin/git --git-dir=$HOME/.dots/ --work-tree=$HOME remote set-url origin git@github.com:XelK/dots.git
