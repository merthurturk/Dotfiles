#!/bin/bash

if command -v code &> /dev/null; then
  echo "Checking for uninstalled VSCode extensions..."

  code_extensions=$(sort "$HOME/Documents/Dotfiles/vscode_extensions.txt")
  installed_extensions=$(code --list-extensions | sort)

  uninstalled_extensions=$(comm -23 <(echo "$code_extensions") <(echo "$installed_extensions"))

  if [ -z "$uninstalled_extensions" ]; then
    echo "All good!"
  else
    count=$(echo "$uninstalled_extensions" | wc -l)
    echo "Found $count missing extensions."

    while IFS= read -r extension; do
      echo "Installing $extension..."
      code --install-extension "$extension"
    done <<< "$uninstalled_extensions"

    echo "Done!"
  fi
fi