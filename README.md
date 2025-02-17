# dot_server

Basic dotfiles to make easier to live in a server.

```sh
# Clone the repo
git clone git@github.com:juanro/dot_server.git ~
mv .config/ .config.old/
mv dot_server/ .config/

# Depending on your distribution you would need
# only the bashrc file, or both profile and bashrc
#
# Symlink the files:
ln -s ~/.config/bash/bash_logout ~/.bash_logout
ln -s ~/.config/bash/bashrc ~/.bashrc
ln -s ~/.config/bash/profile ~/.profile

# optional:
ln -s ~/.config/vim/vimrc ~/.vimrc

# load them in the current shell session
source ~/.bashrc
```
