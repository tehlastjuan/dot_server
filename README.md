# dot_server

Basic config files conceived ideally to make live easier on a remote server. Tweak them to fit your purpose.

Check out `bash/exports` for the exported env variables.

Suggestions are very welcome!

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
```

Or run the `update_env.sh` script included.

---

### Update scripts

#### `update_env.sh`

Sets up dotfiles symlinks at the `$HOME` directory.

#### `update_utils.sh`

Fetches / updates the "utils" binaries for arm64 and amd64 linux platforms.

`bat` : [https://github.com/sharkdp/bat/releases](https://github.com/sharkdp/bat/releases)  
`fzf` : [https://github.com/junegunn/fzf/releases](https://github.com/junegunn/fzf/releases)  
`lf ` : [https://github.com/gokcehan/lf/releases](https://github.com/gokcehan/lf/releases)

#### `update_debian.sh`

Updates and hardens a debian installation and installs the `docker` packages as a bonus.

---

#### A note on safety:

_IMPORTANT!_ Read through **any** script downloaded from the internet before running them.  
If you don't understand what they are doing, don't run them!

---

#### Big thanks to

- [Rafi](https://github.com/rafi/.config.git)
- [MariaSolOs](https://github.com/MariaSolOs/dotfiles.git)

for their inspiration and knowledge (and raw code).
