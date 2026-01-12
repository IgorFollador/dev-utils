#!/bin/bash

# Desinstalador para scripts dev-utils
# Remove scripts e symlinks de /usr/local/bin/
# Uso: sudo ./uninstall.sh

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Diretórios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/usr/local/bin/dev-utils"
BIN_DIR="/usr/local/bin"

echo -e "${BLUE}=== Desinstalador dev-utils ===${NC}"
echo ""

# Verifica se a instalação existe
if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Aviso: Não há instalação encontrada em $INSTALL_DIR${NC}"
    echo "Nada para desinstalar."
    exit 0
fi

# Lista os scripts instalados
INSTALLED_SCRIPTS=()
if [ -d "$INSTALL_DIR" ]; then
    while IFS= read -r -d '' script_file; do
        script_name=$(basename "$script_file")
        INSTALLED_SCRIPTS+=("$script_name")
    done < <(find "$INSTALL_DIR" -type f -print0 2>/dev/null)
fi

if [ ${#INSTALLED_SCRIPTS[@]} -eq 0 ]; then
    echo -e "${YELLOW}Aviso: Nenhum script encontrado em $INSTALL_DIR${NC}"
    echo "Removendo diretório vazio..."
    sudo rmdir "$INSTALL_DIR" 2>/dev/null || true
    exit 0
fi

# Mostra o que será removido
echo -e "${BLUE}Scripts instalados encontrados:${NC}"
for script in "${INSTALLED_SCRIPTS[@]}"; do
    echo "  - $script"
done
echo ""

# Solicita confirmação
echo -e "${YELLOW}Isso removerá:${NC}"
echo "  - Todos os scripts em $INSTALL_DIR"
echo "  - Todos os symlinks correspondentes em $BIN_DIR"
echo "  - O diretório $INSTALL_DIR"
echo ""
read -p "Deseja continuar? (s/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
    echo -e "${YELLOW}Desinstalação cancelada.${NC}"
    exit 0
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

echo ""
echo -e "${BLUE}Iniciando desinstalação...${NC}"
echo ""

REMOVED_SYMLINKS=0
FAILED_SYMLINKS=0
REMOVED_SCRIPTS=0

# Remove symlinks e scripts
for script_name in "${INSTALLED_SCRIPTS[@]}"; do
    script_base="${script_name%.sh}"  # Remove extensão se houver
    
    # Remove symlink se existir
    symlink_path="$BIN_DIR/$script_base"
    if [ -L "$symlink_path" ] || [ -f "$symlink_path" ]; then
        # Verifica se o symlink aponta para nosso diretório
        if [ -L "$symlink_path" ]; then
            link_target=$(readlink "$symlink_path" || true)
            if [[ "$link_target" == "$INSTALL_DIR"* ]]; then
                echo -n "  Removendo symlink: $symlink_path ... "
                if sudo rm -f "$symlink_path" 2>/dev/null; then
                    echo -e "${GREEN}OK${NC}"
                    REMOVED_SYMLINKS=$((REMOVED_SYMLINKS + 1))
                else
                    echo -e "${RED}FALHOU${NC}"
                    FAILED_SYMLINKS=$((FAILED_SYMLINKS + 1))
                fi
            else
                echo -e "${YELLOW}  Ignorando symlink $symlink_path (não aponta para dev-utils)${NC}"
            fi
        else
            # Se não é symlink, pode ser um arquivo normal - não removemos por segurança
            echo -e "${YELLOW}  Ignorando arquivo normal: $symlink_path (não é symlink)${NC}"
        fi
    fi
done

echo ""

# Remove o diretório de instalação
if [ -d "$INSTALL_DIR" ]; then
    echo -n "Removendo diretório: $INSTALL_DIR ... "
    if sudo rm -rf "$INSTALL_DIR" 2>/dev/null; then
        echo -e "${GREEN}OK${NC}"
        REMOVED_SCRIPTS=${#INSTALLED_SCRIPTS[@]}
    else
        echo -e "${RED}FALHOU${NC}"
        echo -e "${RED}Erro: Não foi possível remover $INSTALL_DIR${NC}" >&2
        exit 1
    fi
fi

# Resumo final
echo ""
echo -e "${BLUE}=== Resumo da Desinstalação ===${NC}"
echo -e "${GREEN}Symlinks removidos: $REMOVED_SYMLINKS${NC}"
if [ $FAILED_SYMLINKS -gt 0 ]; then
    echo -e "${RED}Symlinks com falha: $FAILED_SYMLINKS${NC}"
fi
echo -e "${GREEN}Scripts removidos: $REMOVED_SCRIPTS${NC}"
echo -e "${GREEN}Diretório removido: $INSTALL_DIR${NC}"
echo ""

if [ $FAILED_SYMLINKS -eq 0 ] && [ $REMOVED_SYMLINKS -gt 0 ]; then
    echo -e "${GREEN}Desinstalação concluída com sucesso!${NC}"
    exit 0
else
    echo -e "${YELLOW}Desinstalação concluída com avisos.${NC}"
    exit 0
fi
