# dot_server

Basic config files conceived ideally to make live easier on a remote server.

Includes (latest as of 2025-06-23) [LF](https://github.com/gokcehan/lf/releases) and [FZF](https://github.com/junegunn/fzf/releases) binaries.

Check out `bash/exports` for the exported env variables.

---

### Installation

```sh
# rename current .config folder, if any
mv .config/ .config.old/

# Clone the repo
git clone https://github.com/tehlastjuan/dot_server.git ~

# rename repo folder
mv dot_server/ .config/

# Symlink the files
ln -s ~/.config/bash/bash_logout ~/.bash_logout
ln -s ~/.config/bash/bashrc ~/.bashrc
ln -s ~/.config/bash/profile ~/.profile
# Depending on your distribution you would need
# profile and bashrc or only the bashrc file

# Optional pluginless vim config
ln -s ~/.config/vim/vimrc ~/.vimrc

# Load them in the current shell session
source ~/.bashrc

# and... enjoy!
```

---

##### Big thanks to

- [Rafi](https://github.com/rafi/.config.git)
- [MariaSolOs](https://github.com/MariaSolOs/dotfiles.git)

for their inspiration and knowledge (and sometimes raw code!).

---

Suggestions are welcome
