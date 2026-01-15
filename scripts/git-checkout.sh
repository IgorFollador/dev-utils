#!/bin/bash

# Script para fazer checkout de uma branch em todos os repositórios Git recursivamente
# Uso: git-checkout <branch> <pasta>

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para exibir ajuda
show_help() {
    echo "Uso: git-checkout <branch> <pasta>"
    echo ""
    echo "Faz checkout de uma branch em todos os repositórios Git encontrados recursivamente na pasta especificada."
    echo "Inclui submódulos Git."
    echo ""
    echo "Argumentos:"
    echo "  branch   Nome da branch para checkout (ex: main, develop, feature/xyz)"
    echo "  pasta    Caminho da pasta a ser varrida (absoluto ou relativo)"
    echo ""
    echo "Exemplo:"
    echo "  git-checkout main /home/user/projects"
    echo "  git-checkout develop ."
    exit 1
}

# Validação de parâmetros
if [ $# -ne 2 ]; then
    echo -e "${RED}Erro: Número incorreto de argumentos${NC}" >&2
    echo ""
    show_help
fi

BRANCH="$1"
DIR_PATH="$2"

# Validação básica do nome da branch
if [ -z "$BRANCH" ]; then
    echo -e "${RED}Erro: Nome da branch não pode ser vazio${NC}" >&2
    exit 1
fi

# Verifica se a pasta existe
if [ ! -d "$DIR_PATH" ]; then
    echo -e "${RED}Erro: Pasta não encontrada: $DIR_PATH${NC}" >&2
    exit 1
fi

# Converte caminho relativo para absoluto
DIR_PATH=$(cd "$DIR_PATH" && pwd)

echo -e "${BLUE}Fazendo checkout da branch '$BRANCH' em repositórios Git${NC}"
echo -e "${BLUE}Pasta base: $DIR_PATH${NC}"
echo ""

# Contadores
TOTAL_REPOS=0
SUCCESS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
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
    
    # Verifica se a branch existe localmente ou remotamente
    cd "$repo_path"
    
    # Verifica se há mudanças não commitadas
    if ! git --git-dir="$git_dir" --work-tree="$repo_path" diff-index --quiet HEAD -- 2>/dev/null; then
        echo -e "${YELLOW}ignorado (há mudanças não commitadas)${NC}"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        return
    fi
    
    # Verifica se a branch existe localmente
    if git --git-dir="$git_dir" --work-tree="$repo_path" show-ref --verify --quiet "refs/heads/$BRANCH" 2>/dev/null; then
        # Branch existe localmente, faz checkout
        if git --git-dir="$git_dir" --work-tree="$repo_path" checkout "$BRANCH" >/dev/null 2>&1; then
            echo -e "${GREEN}OK (checkout local)${NC}"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            REPOS_PROCESSED+=("$repo_path")
        else
            echo -e "${RED}FALHOU${NC}"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        # Tenta buscar a branch remotamente
        if git --git-dir="$git_dir" --work-tree="$repo_path" fetch --quiet 2>/dev/null; then
            # Verifica se a branch existe em algum remote
            if git --git-dir="$git_dir" --work-tree="$repo_path" show-ref --verify --quiet "refs/remotes/origin/$BRANCH" 2>/dev/null || \
               git --git-dir="$git_dir" --work-tree="$repo_path" show-ref --verify --quiet "refs/remotes/upstream/$BRANCH" 2>/dev/null; then
                # Cria a branch localmente rastreando a remota
                if git --git-dir="$git_dir" --work-tree="$repo_path" checkout -b "$BRANCH" "origin/$BRANCH" >/dev/null 2>&1 || \
                   git --git-dir="$git_dir" --work-tree="$repo_path" checkout -b "$BRANCH" "upstream/$BRANCH" >/dev/null 2>&1 || \
                   git --git-dir="$git_dir" --work-tree="$repo_path" checkout --track "origin/$BRANCH" >/dev/null 2>&1 || \
                   git --git-dir="$git_dir" --work-tree="$repo_path" checkout --track "upstream/$BRANCH" >/dev/null 2>&1; then
                    echo -e "${GREEN}OK (checkout remoto)${NC}"
                    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
                    REPOS_PROCESSED+=("$repo_path")
                else
                    echo -e "${RED}FALHOU (erro ao criar branch)${NC}"
                    FAIL_COUNT=$((FAIL_COUNT + 1))
                fi
            else
                echo -e "${YELLOW}ignorado (branch '$BRANCH' não encontrada)${NC}"
                SKIP_COUNT=$((SKIP_COUNT + 1))
            fi
        else
            echo -e "${YELLOW}ignorado (branch '$BRANCH' não encontrada e não foi possível buscar remotos)${NC}"
            SKIP_COUNT=$((SKIP_COUNT + 1))
        fi
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
                            # Resolve o caminho relativo a partir do diretório do submódulo
                            absolute_gitdir=$(cd "$full_submodule_path" && realpath -m "$relative_gitdir" 2>/dev/null || echo "$full_submodule_path/$relative_gitdir")
                            
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
echo -e "${GREEN}Checkout realizado com sucesso: ${SUCCESS_COUNT}${NC}"
if [ $SKIP_COUNT -gt 0 ]; then
    echo -e "${YELLOW}Ignorados: ${SKIP_COUNT}${NC}"
fi
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
