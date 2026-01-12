#!/bin/bash

# Script para configurar user.email em todos os repositórios Git recursivamente
# Uso: git-set-email <email> <pasta>

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para exibir ajuda
show_help() {
    echo "Uso: git-set-email <email> <pasta>"
    echo ""
    echo "Configura o user.email em todos os repositórios Git encontrados recursivamente na pasta especificada."
    echo "Inclui submódulos Git."
    echo ""
    echo "Argumentos:"
    echo "  email    Email a ser configurado (ex: user@example.com)"
    echo "  pasta    Caminho da pasta a ser varrida (absoluto ou relativo)"
    echo ""
    echo "Exemplo:"
    echo "  git-set-email user@example.com /home/user/projects"
    exit 1
}

# Validação de parâmetros
if [ $# -ne 2 ]; then
    echo -e "${RED}Erro: Número incorreto de argumentos${NC}" >&2
    echo ""
    show_help
fi

EMAIL="$1"
DIR_PATH="$2"

# Validação básica de formato de email
if ! [[ "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo -e "${RED}Erro: Formato de email inválido: $EMAIL${NC}" >&2
    exit 1
fi

# Verifica se a pasta existe
if [ ! -d "$DIR_PATH" ]; then
    echo -e "${RED}Erro: Pasta não encontrada: $DIR_PATH${NC}" >&2
    exit 1
fi

# Converte caminho relativo para absoluto
DIR_PATH=$(cd "$DIR_PATH" && pwd)

echo -e "${BLUE}Configurando user.email para '$EMAIL' em repositórios Git${NC}"
echo -e "${BLUE}Pasta base: $DIR_PATH${NC}"
echo ""

# Contadores
TOTAL_REPOS=0
SUCCESS_COUNT=0
FAIL_COUNT=0
REPOS_PROCESSED=()

# Função para processar um repositório Git
process_repo() {
    local repo_path="$1"
    local git_dir="$2"
    
    TOTAL_REPOS=$((TOTAL_REPOS + 1))
    
    echo -n "  [$TOTAL_REPOS] Processando: $repo_path ... "
    
    # Verifica se é um repositório Git válido
    if ! git --git-dir="$git_dir" rev-parse --git-dir >/dev/null 2>&1; then
        echo -e "${YELLOW}ignorado (não é um repositório Git válido)${NC}"
        return
    fi
    
    # Configura o email no repositório
    if git --git-dir="$git_dir" --work-tree="$repo_path" config --local user.email "$EMAIL" 2>/dev/null; then
        echo -e "${GREEN}OK${NC}"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        REPOS_PROCESSED+=("$repo_path")
    else
        echo -e "${RED}FALHOU${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# Busca recursiva por diretórios .git
echo -e "${BLUE}Buscando repositórios Git...${NC}"

# Usa find para localizar todos os diretórios .git
# Exclui .git/modules para evitar processar submódulos duas vezes
while IFS= read -r -d '' git_dir; do
    # Obtém o diretório pai (repositório)
    repo_path=$(dirname "$git_dir")
    
    # Ignora se estiver dentro de .git/modules (submódulos são processados separadamente)
    if [[ "$git_dir" == *"/.git/modules/"* ]]; then
        continue
    fi
    
    process_repo "$repo_path" "$git_dir"
done < <(find "$DIR_PATH" -name ".git" -type d -print0 2>/dev/null)

# Processa submódulos Git
echo ""
echo -e "${BLUE}Processando submódulos Git...${NC}"

# Busca por arquivos .gitmodules
while IFS= read -r -d '' gitmodules_file; do
    # Obtém o diretório do repositório pai
    parent_repo=$(dirname "$gitmodules_file")
    
    echo "  Submódulos em: $parent_repo"
    
    # Processa cada submódulo listado no .gitmodules
    if [ -f "$gitmodules_file" ]; then
        # Extrai o caminho de cada submódulo
        while IFS= read -r submodule_path; do
            if [ -n "$submodule_path" ]; then
                full_submodule_path="$parent_repo/$submodule_path"
                
                # Verifica se o submódulo existe e tem um .git
                if [ -d "$full_submodule_path/.git" ] || [ -f "$full_submodule_path/.git" ]; then
                    # Para submódulos, o .git pode ser um arquivo apontando para .git/modules
                    if [ -f "$full_submodule_path/.git" ]; then
                        # Lê o caminho do gitdir do arquivo
                        gitdir_line=$(grep "^gitdir:" "$full_submodule_path/.git" 2>/dev/null || true)
                        if [ -n "$gitdir_line" ]; then
                            relative_gitdir=$(echo "$gitdir_line" | sed 's/^gitdir: *//')
                            absolute_gitdir="$parent_repo/.git/$relative_gitdir"
                            
                            # Normaliza o caminho
                            if [ -d "$absolute_gitdir" ]; then
                                process_repo "$full_submodule_path" "$absolute_gitdir"
                            fi
                        fi
                    else
                        process_repo "$full_submodule_path" "$full_submodule_path/.git"
                    fi
                fi
            fi
        done < <(git config --file "$gitmodules_file" --get-regexp path | sed 's/^submodule\.[^.]*\.path //' 2>/dev/null || true)
    fi
done < <(find "$DIR_PATH" -name ".gitmodules" -type f -print0 2>/dev/null)

# Resumo final
echo ""
echo -e "${BLUE}=== Resumo ===${NC}"
echo -e "Total de repositórios encontrados: ${TOTAL_REPOS}"
echo -e "${GREEN}Configurados com sucesso: ${SUCCESS_COUNT}${NC}"
if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "${RED}Falhas: ${FAIL_COUNT}${NC}"
fi

if [ $SUCCESS_COUNT -gt 0 ]; then
    echo ""
    echo -e "${GREEN}Repositórios processados:${NC}"
    for repo in "${REPOS_PROCESSED[@]}"; do
        echo "  - $repo"
    done
fi

exit 0
