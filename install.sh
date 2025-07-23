#!/bin/bash

TOML_FILE="package.toml"

get_value_from_toml() {
  local key="$1"
  grep "^$key\s*=" "$TOML_FILE" | sed -E 's/.*= "(.*)"/\1/' | tr -d '\r'
}

get_files_from_toml() {
  local line
  line=$(grep '^include\s*=' "$TOML_FILE" | head -n 1)
  line=${line#*=}
  line=$(echo "$line" | tr -d '[]" ')
  echo "$line" | tr ',' '\n'
}

detect_tex_distribution() {
    if command -v tlmgr > /dev/null 2>&1; then
        TEX_DISTRO="texlive"
    elif command -v miktex > /dev/null 2>&1; then
        TEX_DISTRO="miktex"
    else
        echo "No supported TeX distribution found"
        exit 1
    fi
}

get_texmf_path() {
    case "$TEX_DISTRO" in
        "texlive")
            TEXMF_PATH=$(kpsewhich -var-value=TEXMFLOCAL)
            ;;
        "miktex")
            TEXMF_PATH=$(miktex-console --get-setting=CommonInstall 2>/dev/null)
            if [ -z "$TEXMF_PATH" ]; then
                echo "Cannot determine MiKTeX TEXMF path."
                exit 1
            fi
            ;;
    esac
}

install_package_files() {
    INSTALL_DIR="$TEXMF_PATH/tex/latex/$PACKAGE_NAME"
    
    if [ ! -d "$INSTALL_DIR" ]; then
        sudo mkdir -p "$INSTALL_DIR"
    fi

    for f in $PACKAGE_FILES; do
      if [ ! -f "$f" ]; then
        echo "File $f not found. Aborting."
        exit 1
      fi
      echo "Copying $f to $INSTALL_DIR"
      sudo cp "$f" "$INSTALL_DIR/"
    done

    case "$TEX_DISTRO" in
        "texlive")
            if command -v mktexlsr > /dev/null 2>&1; then
                sudo mktexlsr
                echo "Package $PACKAGE_NAME version $PACKAGE_VERSION installed successfully!"
            else
                echo "mktexlsr not found or not executable."
                exit 1
            fi
            ;;
        "miktex")
            sudo PATH=$PATH miktex-console --update-fndb
            if [ $? -eq 0 ]; then
                echo "Package $PACKAGE_NAME version $PACKAGE_VERSION installed successfully!"
            else
                echo "Failed to update MiKTeX file database."
                exit 1
            fi
            ;;
    esac
}

main() {
    PACKAGE_NAME=$(get_value_from_toml "name")
    PACKAGE_VERSION=$(get_value_from_toml "version")
    PACKAGE_FILES=$(get_files_from_toml)
    detect_tex_distribution
    get_texmf_path
    install_package_files
}

main