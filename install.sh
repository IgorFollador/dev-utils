#!/bin/bash

# Instalador para scripts dev-utils
# Copia scripts para /usr/local/bin/dev-utils/ e cria symlinks
# Uso: sudo ./install.sh

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Diretórios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_SOURCE_DIR="$SCRIPT_DIR/scripts"
INSTALL_DIR="/usr/local/bin/dev-utils"
BIN_DIR="/usr/local/bin"

echo -e "${BLUE}=== Instalador dev-utils ===${NC}"
echo ""

# Verifica se está sendo executado do diretório correto
if [ ! -d "$SCRIPTS_SOURCE_DIR" ]; then
    echo -e "${RED}Erro: Pasta 'scripts' não encontrada!${NC}" >&2
    echo "Execute este script a partir do diretório dev-utils." >&2
    exit 1
fi

# Verifica se existem scripts para instalar
if [ -z "$(find "$SCRIPTS_SOURCE_DIR" -name "*.sh" -type f 2>/dev/null)" ]; then
    echo -e "${YELLOW}Aviso: Nenhum script .sh encontrado em $SCRIPTS_SOURCE_DIR${NC}" >&2
    exit 1
fi

# Verifica privilégios de administrador
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        # Testa se pode escrever em /usr/local/bin
        if [ ! -w "$BIN_DIR" ] && [ ! -w "$(dirname "$BIN_DIR")" ]; then
            echo -e "${RED}Erro: Este script requer privilégios de administrador (sudo)${NC}" >&2
            echo ""
            echo "Execute com: sudo $0"
            exit 1
        fi
    fi
}

check_sudo

# Verifica se /usr/local/bin existe
if [ ! -d "$BIN_DIR" ]; then
    echo -e "${YELLOW}Aviso: $BIN_DIR não existe. Tentando criar...${NC}"
    sudo mkdir -p "$BIN_DIR" || {
        echo -e "${RED}Erro: Não foi possível criar $BIN_DIR${NC}" >&2
        exit 1
    }
fi

# Cria o diretório de instalação se não existir
echo -e "${BLUE}Criando diretório de instalação: $INSTALL_DIR${NC}"
sudo mkdir -p "$INSTALL_DIR" || {
    echo -e "${RED}Erro: Não foi possível criar $INSTALL_DIR${NC}" >&2
    exit 1
}
echo -e "${GREEN}✓ Diretório criado${NC}"
echo ""

# Função para instalar um script
install_script() {
    local script_file="$1"
    local script_name=$(basename "$script_file")
    local script_base="${script_name%.sh}"
    local target_script="$INSTALL_DIR/$script_base"
    local symlink_path="$BIN_DIR/$script_base"
    
    echo -e "${BLUE}Instalando: $script_name${NC}"
    
    # Copia o script
    sudo cp "$script_file" "$target_script" || {
        echo -e "${RED}  ✗ Falha ao copiar script${NC}" >&2
        return 1
    }
    
    # Define permissão de execução
    sudo chmod +x "$target_script" || {
        echo -e "${RED}  ✗ Falha ao definir permissões${NC}" >&2
        return 1
    }
    
    # Remove symlink existente se houver (para atualizar)
    if [ -L "$symlink_path" ] || [ -f "$symlink_path" ]; then
        sudo rm -f "$symlink_path"
    fi
    
    # Cria symlink
    sudo ln -sf "$target_script" "$symlink_path" || {
        echo -e "${RED}  ✗ Falha ao criar symlink${NC}" >&2
        return 1
    }
    
    echo -e "${GREEN}  ✓ Instalado: $script_base${NC}"
    echo "    Script: $target_script"
    echo "    Symlink: $symlink_path -> $target_script"
    echo ""
    
    return 0
}

# Varre e instala todos os scripts .sh
INSTALLED_COUNT=0
FAILED_COUNT=0

echo -e "${BLUE}Instalando scripts...${NC}"
echo ""

for script_file in "$SCRIPTS_SOURCE_DIR"/*.sh; do
    if [ -f "$script_file" ]; then
        if install_script "$script_file"; then
            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
        else
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
    fi
done

# Resumo
echo -e "${BLUE}=== Resumo da Instalação ===${NC}"
echo -e "${GREEN}Scripts instalados: $INSTALLED_COUNT${NC}"
if [ $FAILED_COUNT -gt 0 ]; then
    echo -e "${RED}Falhas: $FAILED_COUNT${NC}"
fi
echo ""

# Verifica se /usr/local/bin está no PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo -e "${YELLOW}Aviso: $BIN_DIR não está no PATH atual${NC}"
    echo "Você pode precisar reabrir o terminal ou executar:"
    echo "  export PATH=\"$BIN_DIR:\$PATH\""
    echo ""
else
    echo -e "${GREEN}✓ $BIN_DIR está no PATH${NC}"
    echo ""
fi

if [ $INSTALLED_COUNT -gt 0 ]; then
    echo -e "${GREEN}Instalação concluída com sucesso!${NC}"
    echo ""
    echo "Os comandos estão disponíveis diretamente:"
    for script_file in "$SCRIPTS_SOURCE_DIR"/*.sh; do
        if [ -f "$script_file" ]; then
            script_name=$(basename "$script_file")
            script_base="${script_name%.sh}"
            echo "  - $script_base"
        fi
    done
    echo ""
    echo "Para desinstalar, execute: sudo $SCRIPT_DIR/uninstall.sh"
else
    echo -e "${RED}Nenhum script foi instalado${NC}" >&2
    exit 1
fi

exit 0
