#!/usr/bin/env bash

# Descomentar a linha abaixo para ativar debug
set -xeuo pipefail

## INFO ##
## NOME.............: dhcp.sh
## VERSÃO...........: 1.0
## DESCRIÇÃO........: Realizar ajustes após instalação basica do sistema
## DATA DA CRIAÇÃO..: 16/06/2024
## ESCRITO POR......: Bruno Lima
## E-MAIL...........: bruno@lc.tec.br
## DISTRO...........: Rocky GNU/Linux
## VERSÃO HOMOLOGADA: 8 e 9 
## LICENÇA..........: GPLv3
## Git Hub..........: https://github.com/bflima

# Funções
################################################################################
# Função para exibir mensagem de erro, usando o programa whiptail.
_MSG_ERRO_INFO() { clear ; whiptail --title "Erro" --msgbox "Erro" 0 0 ; exit 20 ; }

################################################################################
# Função para exibir mensagem de erro e sair do script com código de erro 30.
_MSG_SAIR(){ clear ; whiptail --title "Aviso" --msgbox "$1" 0 0 ; exit 30 ; }

################################################################################
# Função para verificar se o script pode ser executado com privilegios de root.
_VERIFICAR_ROOT(){ [[ "$EUID" -eq 0 ]] || _MSG_ERRO_INFO "Necessita permissão de root" ; }

################################################################################
# Função para verificar o sistema operacional Rocky Linux.
_VERIFICAR_OS(){ grep -Eoq 'centos|rocky|rhel' /etc/os-release|| _MSG_ERRO_INFO "Sistema operacional não homologado, Favor usar Rocky Linux" ; }

################################################################################
# Função para remover informações, ao realizar acesso.
_ESCONDER_BANNER(){
  # Declaração de variáveis
  ISSUE=$(find /etc/ -iname issue)
  ISSUENET=$(find /etc/ -iname issue.net)
  MOTD=$(find /etc/ -iname motd)
  MSG_BANNER='Acesso ao sistema monitorado'

  # Alterar a mensagem padrão para acesso ao sistema por ssh.
  echo "$MSG_BANNER" > "$ISSUE"
  echo "$MSG_BANNER" > "$ISSUENET"
  echo "$MSG_BANNER" > "$MOTD"
}

################################################################################
# Função para realizar instalação de pacotes
_INSTALAR_PACOTES(){
  # Declaração de variáveis
  PACOTES='nano vim bash-completion yum-utils whiptail' 

  # Realizar a instalação dos pacotes acima
  for pacote in $PACOTES
    do command -v > /dev/null  "$pacote" || yum install -y "$pacote"
  done
}

################################################################################
# Função para desativar o firewalld (NÂO RECOMENDADO)
_DESATIVAR_FIREWALL(){
  if whiptail --title "Aviso - Ação não recomendada" --yesno "Deseja desativar firewalld ?" 10 50 --defaultno 
    then
     systemctl stop firewalld
     systemctl disable firewalld
  fi
}

################################################################################
# Função para desativar o firewalld (NÂO RECOMENDADO)
_DESATIVAR_SELINUX(){
  if whiptail --title "Aviso - Ação não recomendada" --yesno "Deseja desativar Selinux ?" 10 50 --defaultno 
    then
      setenforce 0
      ARQ_SELINUX=$(find /etc/ -type f -iname config | grep selinux)
      sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' "$ARQ_SELINUX"
      setenforce 0
  fi
}

# Função para ajustar o timezone
_AJUSTAR_TIMEZONE(){ timedatectl set-timezone 'America/Sao_Paulo' ; }

# Função para ajustar o timezone
_AJUSTAR_TECLADO(){ localectl set-keymap br-abnt2 ; }

# Função para ajustar o hostname
_AJUSTAR_HOSTNAME(){
  HOSTNAME=$(whiptail --title "Informe o hostname e dominio:" --inputbox "Ex:linux.lab.local\nAtual: $(hostname)" --fb 10 60 3>&1 1>&2 2>&3)
  HOSTNAME=${HOSTNAME:='rocky'}
  hostnamectl set-hostname "$HOSTNAME"
}
################################################################################
# Função para ajustar o tamanho quantidade e hora da execução do comando
_AJUSTAR_HISTORICO(){
BASH_RC=$(find "$HOME" -iname .bashrc)

grep -qi 'CONF_BASH' "$BASH_RC" || \
cat >> "${BASH_RC}" << EOF
## CONF_BASH ##
export HISTCONTROL='ignoreboth'
export HISTIGNORE='ls:ls -lah:history:pwd:htop:bg:fg:clear'
export HISTTIMEFORMAT="%F %T$ "
export PROMPT_COMMAND='history -a'
export HISTSIZE=10000
export HISTFILESIZE=20000

shopt -s histappend
shopt -s cmdhist
EOF
}
################################################################################
# Função para criar novo usuário
_CRIAR_USUARIO_ACESSO(){
  clear
  USUARIO=$(whiptail --title "Deseja criar novo usuário de acesso" --inputbox "Digite o nome de usuário" --fb 10 60 3>&1 1>&2 2>&3)
  USUARIO=${USUARIO:=lc}
  grep -iq "$USUARIO" /etc/passwd || { useradd "$USUARIO" ; passwd "$USUARIO" ; } 
}

################################################################################

# Inicio do script

# Checar OS está homologado para distros baseadas em redhat
_VERIFICAR_OS         || _MSG_ERRO_INFO 'Erro ao executar função: _VERIFICAR_OS '

# Checar se o script tem permissão de root para execução
_VERIFICAR_ROOT       || _MSG_ERRO_INFO 'Erro ao executar função: _VERIFICAR_ROOT '

# Realizar a troca das mensagens padrão do sistema
_ESCONDER_BANNER      || _MSG_ERRO_INFO 'Erro ao executar função: _ESCONDER_BANNER  '

# Instalar pacotes basicos
_INSTALAR_PACOTES     || _MSG_ERRO_INFO 'Erro ao executar função: _INSTALAR_PACOTES '

# Desativar firewalld
_DESATIVAR_FIREWALL   || _MSG_ERRO_INFO 'Erro ao executar função: _DESATIVAR_FIREWALL '

# Desativar Selinux
_DESATIVAR_SELINUX    || _MSG_ERRO_INFO 'Erro ao executar função:  _DESATIVAR_SELINUX'

# Ajustes locais
_AJUSTAR_TIMEZONE     || _MSG_ERRO_INFO 'Erro ao executar função:  _AJUSTAR_TIMEZONE'
_AJUSTAR_TECLADO      || _MSG_ERRO_INFO 'Erro ao executar função:  _AJUSTAR_TECLADO'
_AJUSTAR_HOSTNAME     || _MSG_ERRO_INFO 'Erro ao executar função:  _AJUSTAR_HOSTNAME'
_AJUSTAR_HISTORICO    || _MSG_ERRO_INFO 'Erro ao executar função:  _AJUSTAR_HISTORICO'
_CRIAR_USUARIO_ACESSO || _MSG_ERRO_INFO 'Erro ao executar função:  _CRIAR_USUARIO_ACESSO'

# Reiniciar o servidor
if whiptail --title "Aplicar Configurações realizadas" --yesno "Deseja reiniciar o servidor" 10 50 --defaultno ; then reboot ; fi 

# Fim script
