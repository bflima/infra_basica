#!/usr/bin/env bash

# Descomentar a linha abaixo para ativar debug
# set -xeuo pipefail

## INFO ##
## NOME.............: dhcp.sh
## VERSÃO...........: 1.0
## DESCRIÇÃO........: Instala serviço dhcp
## DATA DA CRIAÇÃO..: 18/05/2024
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
# Função para validar endereço ip usando o programaa externo ipcalc.
_VALIDAR_IP()
{
  which ipcalc 1> /dev/null || yum -y install ipcalc 1> /dev/null
  IPCALC=$(which ipcalc)
  "$IPCALC" -c "$1" || { clear ; echo "Erro ao informar IP" ;  exit 20 ; }
  echo "$1"
}

################################################################################
# Função para selecionar a interface de rede. (Ex: enp0s3)
_INTERFACE()
{
  NOME_IFACE_TMP=$(ip -o -4 route show to default | awk '{print $5}' | uniq)
  NOME_IFACE=$(ip -o -4 route show to default     | awk '{print $5}' | uniq | tail -n 1)

  arr=()
  i=0
  for ip in $NOME_IFACE_TMP
  do
    #echo "${ip[i]}"
    arr=("${ip[i]}" "${arr[@]}")
  done

  whiptail_args=(
    --title "Escolha a interface de rede"
    --radiolist "Interface disponivel:"
    10 80 "${#arr[@]}"
  )

  i=0
  for db in "${arr[@]}"; do
    whiptail_args+=( "$((++i))" "$db" )
    if [[ $db = "$NOME_IFACE" ]]; then
      whiptail_args+=( "on" )
    else
      whiptail_args+=( "off" )
    fi
  done

  indice=$(whiptail "${whiptail_args[@]}" 3>&1 1>&2 2>&3)
  echo "${arr[${indice}-1]}"
}

################################################################################

# Inicio do script
_VERIFICAR_ROOT
_VERIFICAR_OS

# Declaração de variáveis
ISSUE=$(find /etc/ -iname issue)
ISSUENET=$(find /etc/ -iname issue.net)
MOTD=$(find /etc/ -iname motd)
MSG_BANNER='Acesso ao sistema monitorado'

# Alterar a mensagem padrão para acesso ao sistema por ssh.
echo "$MSG_BANNER" > "$ISSUE"
echo "$MSG_BANNER" > "$ISSUENET"
echo "$MSG_BANNER" > "$MOTD"


# Verificar se firewalld está ativo, cadastrar um regra para permitir o serviço de dhcp(UDP porta 67,68)
firewall-cmd --state | grep -iq running && { firewall-cmd --zone=public --add-service=dhcp --permanent ; firewall-cmd --reload ; }

# Realizar confirmação de instalação do serviço
if whiptail --title "Aviso" --yesno "Deseja instalar e configurar o serviço dhcp? " 10 50 ; then yum update -y ; yum upgrade -y ; yum install dhcp-server -y ; else _MSG_SAIR 'Operação Cancelada'; fi 

clear
# Informar o gateway da rede
GW_ATUAL=$(ip -o -4 route show to default | awk '{print $3}' | head -n 1)
GW=$(whiptail --title "Favor inserir o default gateway"\
              --inputbox "[$GW_ATUAL]" --fb 10 60 3>&1 1>&2 2>&3) || _MSG_SAIR 'Operação cancelada'
# Define gateway atual do sistema se campo estiver em branco
GW=${GW:=$GW_ATUAL}
_VALIDAR_IP "$GW"

# Informar o ip e máscara de rede
IP_REDE_ATUAL=$(ip route | tail -n +2 | awk '{print $1}')
IP_REDE=$(whiptail --title "Favor inserir o endereço IP e netmask:"                                                     \
                   --inputbox "Exemplo:\n192.168.0.0/24\n192.168.0.0/255.255.255.0\n\nRede Atual: [$IP_REDE_ATUAL]"     \
                   --fb 15 60 3>&1 1>&2 2>&3) || _MSG_SAIR 'Operação Cancelada'
IP_REDE=${IP_REDE:=$IP_REDE_ATUAL}
_VALIDAR_IP "$IP_REDE"

# Informar o escopo inicial
IP_INI_100=$(ip route | tail -n +2 | awk '{print $1}' | cut -d '/' -f1 | sed -r 's/([0-9.]+)([0-9]$)/\1100/g')
IP_INI=$(whiptail --title "Favor inserir o endereço IP de escopo inicial:"      \
                   --inputbox "Exemplo:\n[$IP_INI_100]"                         \
                   --fb 15 60 3>&1 1>&2 2>&3) || _MSG_SAIR 'Operação Cancelada'
IP_INI=${IP_INI:=$IP_INI_100}
_VALIDAR_IP "$IP_INI"

# Informar o escopo final
IP_FIM_200=$(ip route | tail -n +2 | awk '{print $1}' | cut -d '/' -f1 | sed -r 's/([0-9.]+)([0-9]$)/\1200/g')
IP_FIM=$(whiptail --title "Favor inserir o endereço IP de escopo final:"        \
                   --inputbox "Exemplo:\n[$IP_FIM_200]"                         \
                   --fb 15 60 3>&1 1>&2 2>&3) || _MSG_SAIR 'Operação Cancelada'
IP_FIM=${IP_FIM:=$IP_FIM_200}
_VALIDAR_IP "$IP_FIM"

# Informar o DNS primario
DNS_PRI=$(whiptail --title "Favor inserir o endereço DNS INICIAL:"              \
                   --inputbox "Exemplo:\n[1.1.1.1]"                             \
                   --fb 15 60 3>&1 1>&2 2>&3) || _MSG_SAIR 'Operação Cancelada'
DNS_PRI=${DNS_PRI:=1.1.1.1}
_VALIDAR_IP "$DNS_PRI"

# Informar o DNS secundário
DNS_SEC=$(whiptail --title "Favor inserir o endereço DNS INICIAL:"              \
                   --inputbox "Exemplo:\n[8.8.8.8]"                             \
                   --fb 15 60 3>&1 1>&2 2>&3) || _MSG_SAIR 'Operação Cancelada'
DNS_SEC=${DNS_SEC:=8.8.8.8}
_VALIDAR_IP "$DNS_SEC"

# Selecionar interface de rede disponível para serviço dhcp
INTERFACE=$(_INTERFACE)   || _MSG_SAIR "$SAMBA_ERRO_MSG"

# Informar o dominio
DOMINIO=$(whiptail --title "Favor inserir o dominio:"  \
                   --inputbox "Exemplo:\nempresa.corp" \
                   --fb 15 60 3>&1 1>&2 2>&3) || _MSG_SAIR 'Operação Cancelada'

# Tratamento de variáveis
DOMINIO=${DOMINIO:=$(hostname -f)}
BROADCAST=$(ipcalc -b "$IP_REDE")
NETMASK=$(ipcalc   -m "$IP_REDE")

# Verificar dados fornecidos estão corretos
if ! whiptail --title "Dados informados pelo usuario" \
  --yesno "Os dados estao corretos ?\n
  ENDEREÇO DE REDE...=$IP_REDE
  ENDEREÇO INICIAL...=${IP_REDE%%/*}
  MASCARA DE REDE....=${NETMASK##*=}
  BROADCAST..........=${BROADCAST##*=}
  END INI DO ESCOPO..=$IP_INI
  END FIN DO ESCOPO..=$IP_FIM
  DEFAULT GATEWAY....=$GW
  NAMESERVER 1.......=$DNS_PRI
  NAMESERVER 2.......=$DNS_SEC
  DOMINIO............=$DOMINIO" --fb 0 0
then
  _MSG_SAIR 'Operação Cancelada'
fi

# Verificar se interface de rede está com ip fixo para o serviço
DHCP_ENABLED=$(find /etc/ -iname "*""$INTERFACE""*")
MSG="Favor configurar ip fixo para o serviço dhcp na inteface de rede $INTERFACE"
grep -E 'method=auto|dhcp' "$DHCP_ENABLED" && whiptail --title "Alerta:" --msgbox "$MSG" --fb 0 0  3>&1 1>&2 2>&3

# Verificar se o endreço de ip inicial é menor que o final
[[ "${IP_INI##*\.}" -gt "${IP_FIM##*\.}" ]] && _MSG_SAIR 'Escopo final menor que o inicial'

# Arquivo de configuração do dhcp
DHCP=$(find /etc/ -iname dhcpd.conf)

# Realizar backup do arquivo de configuração inical
\cp "$DHCP"{,.orig}

cat > "$DHCP" << EOF
# 691200 segundos (8 dias)

ddns-update-style none;
# deny unknown-clients;
subnet ${IP_REDE%%/*} netmask ${NETMASK##*=} { 
        server-identifier SERVIDOR_DHCP;
        authoritative;
        range $IP_INI $IP_FIM;
        interface $INTERFACE;
        option domain-name "$DOMINIO";
        option domain-search "$DOMINIO";
        option domain-name-servers $DNS_PRI,$DNS_SEC;
        option broadcast-address ${BROADCAST##*=};
        option routers $GW;
        option ntp-servers a.ntp.br,b.ntp.br;
        default-lease-time 691200;
        max-lease-time 791200;
}

# Reservas descomentar para cadastro e uso as linhas abaixo

# host cliente-interno {
#       hardware ethernet 08:00:27:0b:91:4c;
#       fixed-address 192.168.1.100;
#}
EOF

# Reiniciar o serviço
if whiptail --title "Aviso" --yesno "Deseja iniciar serviço dhcp? " 10 50 ; then systemctl restart NetworkManager; systemctl enable dhcpd ; systemctl restart dhcpd ; else _MSG_SAIR 'Operação Cancelada'; fi 

# Fim do script
