# dot_server

Basic dotfiles to make easier to live in a server.

```sh
# Clone the repo
git clone git@github.com:juanro/dot_server.git ~/.config
mv .config/dot_server/*.* ~/.config
rm -r ~/.config/dot_server

# Symlink shell files manually:
cd ~
ln -s .config/bash/bashrc .bashrc
ln -s .config/bash/profile .profile
ln -s .config/vim/vimrc .vimrc
source .profile
```

