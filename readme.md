# Initial Setup

Make sure that all commands under `bin` directory are executable by running the following:

```bash
chmod +x ./bin/*
```

# Instructions for Linking Dotfiles

To link the dotfiles to their appropriate locations, use the following steps:

1. Open a terminal and navigate to the directory containing your dotfiles:
    ```bash
    cd ~/Documents/Dotfiles
    ```

2. Use symbolic links (`ln -s`) to link each dotfile to its corresponding location. For example:
    ```bash
    ln -s ~/Documents/Dotfiles/aerospace.toml ~/.aerospace.toml
    ```

3. Reload your shell or restart your terminal to apply the changes.

**Note:** Adjust the file paths as needed for your specific setup.

# Instructions for Brewfile

Create and update a `Brewfile` from your current setup:

```bash
brew bundle dump --file=~/Dotfiles/Brewfile --force
```

Use the `Brewfile` on a new machine:

```bash
brew bundle --file=~/Dotfiles/Brewfile
```

This will install everything listed in the file.

# Instructions for Visual Studio Code

Save a list of all extensions in your Visual Studio Code:

```bash
./bin/save_vscode_extensions.sh
```

1. Open a terminal and navigate to the directory containing your dotfiles:
    ```bash
    cd ~/Documents/Dotfiles
    ```

2. Use symbolic links (`ln -s`) to link each dotfile to its corresponding location. For example:
    ```bash
    ln -s ~/Documents/Dotfiles/visual-studio-code/keybindings.json ~/Library/Application\ Support/Code/User/keybindings.json
    ln -s ~/Documents/Dotfiles/visual-studio-code/settings.json ~/Library/Application\ Support/Code/User/settings.json
    ```

3. Install all the missing extensions:
    ```bash
    ./bin/install_vscode_extensions.sh
    ```

**Note:** Adjust the file paths as needed for your specific setup.