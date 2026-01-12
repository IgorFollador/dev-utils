# dev-utils

Repositório de utilitários pessoais para uso em sistemas operacionais Linux.

Este repositório contém scripts utilitários que podem ser instalados no sistema e executados diretamente pelo terminal.

## Estrutura

```
dev-utils/
├── scripts/              # Scripts utilitários
│   └── git-set-email.sh  # Script para configurar email em múltiplos repositórios Git
├── install.sh            # Instalador dos scripts
├── uninstall.sh          # Desinstalador dos scripts
└── README.md             # Esta documentação
```

## Instalação

Para instalar os scripts no sistema:

```bash
sudo ./install.sh
```

O instalador irá:
- Copiar todos os scripts `.sh` de `scripts/` para `/usr/local/bin/dev-utils/`
- Criar symlinks em `/usr/local/bin/` para cada script (sem extensão `.sh`)
- Tornar os scripts executáveis
- Disponibilizar os comandos diretamente no PATH

**Nota:** Requer privilégios de administrador (sudo).

## Desinstalação

Para desinstalar todos os scripts:

```bash
sudo ./uninstall.sh
```

O desinstalador irá:
- Remover todos os symlinks criados em `/usr/local/bin/`
- Remover o diretório `/usr/local/bin/dev-utils/` completamente
- Solicitar confirmação antes de desinstalar

## Scripts Disponíveis

### git-set-email

Configura o `user.email` do Git em todos os repositórios encontrados recursivamente dentro de uma pasta. Inclui submódulos Git.

**Uso:**
```bash
git-set-email <email> <pasta>
```

**Argumentos:**
- `email`: Email a ser configurado (ex: `user@example.com`)
- `pasta`: Caminho da pasta a ser varrida (absoluto ou relativo)

**Exemplo:**
```bash
git-set-email user@example.com /home/user/projects
git-set-email dev@company.com .
```

**Funcionalidades:**
- Varre recursivamente todos os diretórios `.git` dentro da pasta especificada
- Processa submódulos Git (arquivos `.gitmodules` e diretórios `.git/modules/`)
- Valida formato de email antes de processar
- Exibe progresso e resumo final (total processado, sucessos, falhas)
- Trata erros graciosamente (repositórios corrompidos, permissões, etc.)

**Validações:**
- Verifica se os parâmetros foram fornecidos
- Valida formato básico de email (regex)
- Verifica se a pasta existe e é acessível
- Verifica se cada diretório `.git` é um repositório Git válido

**Output:**
O script exibe mensagens coloridas indicando:
- Em azul: Informações gerais e progresso
- Em verde: Sucessos
- Em amarelo: Avisos
- Em vermelho: Erros e falhas

Ao final, exibe um resumo com:
- Total de repositórios encontrados
- Quantidade de repositórios configurados com sucesso
- Quantidade de falhas (se houver)
- Lista de repositórios processados

## Requisitos

- Bash 4.0+ (geralmente já instalado por padrão)
- Git instalado
- Privilégios de administrador (sudo) para instalação/desinstalação
- Permissões de leitura/escrita nos repositórios Git a serem processados (apenas para git-set-email)
- `/usr/local/bin` deve estar no PATH (padrão na maioria das distribuições Linux)

## Organização da Instalação

Os scripts são instalados em:
- **Scripts:** `/usr/local/bin/dev-utils/`
- **Symlinks:** `/usr/local/bin/` (ex: `/usr/local/bin/git-set-email`)

Esta organização facilita:
- **Desinstalação:** Basta remover a pasta `/usr/local/bin/dev-utils/` e os symlinks
- **Manutenção:** Scripts organizados em um único diretório
- **Compatibilidade:** Não modifica arquivos de configuração do usuário (`~/.bashrc`, etc.)

## Adicionando Novos Scripts

Para adicionar um novo script utilitário:

1. Crie o script na pasta `scripts/` com extensão `.sh`
2. Garanta que o script tenha permissão de execução (`chmod +x`)
3. Execute `sudo ./install.sh` novamente para instalar o novo script

O instalador detecta automaticamente todos os scripts `.sh` na pasta `scripts/` e os instala.

## Exemplos de Uso

### Configurar email em múltiplos repositórios

```bash
# Configurar email pessoal em todos os projetos do diretório atual
git-set-email pessoa@example.com .

# Configurar email corporativo em todos os projetos de uma pasta específica
git-set-email dev@empresa.com.br /home/user/projetos-empresa

# Usar caminho relativo
git-set-email dev@company.com ../projetos
```

## Troubleshooting

### Erro: "Número incorreto de argumentos"
Certifique-se de fornecer ambos os parâmetros: email e pasta.

### Erro: "Formato de email inválido"
Verifique se o email está no formato correto: `usuario@dominio.com`

### Erro: "Pasta não encontrada"
Verifique se o caminho da pasta está correto e se você tem permissão para acessá-la.

### Scripts não encontrados após instalação
- Verifique se `/usr/local/bin` está no PATH: `echo $PATH`
- Se não estiver, adicione temporariamente: `export PATH="/usr/local/bin:$PATH"`
- Para adicionar permanentemente, adicione a linha acima ao seu `~/.bashrc` ou `~/.zshrc`
- Reabra o terminal após modificar os arquivos de configuração

### Erro ao instalar: "Este script requer privilégios de administrador"
Execute com sudo: `sudo ./install.sh`

## Licença

Este é um repositório pessoal de utilitários. Use como desejar.

## Contribuições

Este é um repositório pessoal. Se você quiser usar ou adaptar os scripts, fique à vontade!
