#!/usr/bin/env bash

# Descomentar a linha abaixo para ativar debug
set -xeuo pipefail

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
## Documentação.....: https://semanacap.bcp.nic.br/files/apresentacao/arquivo/864/Implementacao%20de%20servidores%20recursivos%20guia%20de%20praticas%20semcap%20ceptro%20br.pdf

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
# INICIO
_VERIFICAR_ROOT
_VERIFICAR_OS
clear

# Atualizar sistema
yum update -y && yum upgrade -y

# Pacotes necessários para execução do script
command -v whiptail > /dev/null || yum -y install whiptail -y || _MSG_ERRO_INFO 'Erro ao instalar pacote whiptail'
command -v unbound  > /dev/null || yum -y install unbound  -y || _MSG_ERRO_INFO 'Erro ao instalar pacote unbound'
command -v ipcalc   > /dev/null || yum -y install ipcalc   -y || _MSG_ERRO_INFO 'Erro ao instalar pacote ipcalc'
command -v wget     > /dev/null || yum -y install wget     -y || _MSG_ERRO_INFO 'Erro ao instalar pacote wget'
command -v bc       > /dev/null || yum -y install bc       -y || _MSG_ERRO_INFO 'Erro ao instalar pacote bc'
command -v needs-restarting > /dev/null || yum -y install yum-utils -y || _MSG_ERRO_INFO 'Erro ao instalar pacote needs-restarting'

# Obter ip em uso atualmente
IP_ATUAL=$(ip a | grep inet | grep -v inet6 | grep -v "127.0.0.*" | awk '{print $2}' | cut -d "/" -f 1)
IP_UNBOUND=$(whiptail --title "Favor inserir o ip do serviço de DNS" --inputbox "Ex:\n$IP_ATUAL" --fb 15 60 3>&1 1>&2 2>&3)

# Se escolher cancelar finaliza o script
[[ $? -eq 1 ]] && _MSG_SAIR 'Saindo\nFavor executar novamente o script'
IP_UNBOUND=${IP_UNBOUND:=$IP_ATUAL}

# Verificar se ip é valido 
IPCALC=$(command -v ipcalc)            || _MSG_ERRO_INFO "$IPCALC não encontrado"
"$IPCALC" -c "$IP_UNBOUND" > /dev/null || _MSG_ERRO_INFO "$IP_ATUAL está incorreto"

  # Valor da mascara de rede atual
MASK_ATUAL=$(ip a | grep inet | grep -v inet6 | grep -v "127.0.0.*" | awk '{print $2}' | cut -d "/" -f 2 | uniq)
MASK=$(whiptail --title "Favor inserira a máscara de rede" --inputbox "Ex: $MASK_ATUAL" --fb 10 60 3>&1 1>&2 2>&3)
    
 # Se escolher cancelar finaliza o script
[[ $? -eq 1 ]] && _MSG_ERRO_INFO 'Saindo\nFavor executar novamente o script'
MASK=${MASK:=$MASK_ATUAL}

# Validando máscara de rede e ip.
"$IPCALC" -c "$IP_UNBOUND"/"$MASK" > /dev/null || _MSG_ERRO_INFO "IP: $IP_SAMBA/$MASK está incorreto"

# Ajustar arquivo resolv.conf
RESOLV_CONF=$(find /etc/ -iname resolv.conf)

# desproteger o arquivo
chattr -i "$RESOLV_CONF"

cat > "$RESOLV_CONF" << EOF
nameserver $IP_UNBOUND
nameserver 127.0.0.1
nameserver 1.1.1.1
EOF

# Proteger o arquivo
chattr +i "$RESOLV_CONF"

# Caminhos de configuração dos arquivos unbound
UNBOUND_ROOT_HINTS='/etc/unbound/root.hints'
UNBOUND_ROOT_ZONES='/etc/unbound/root.zone'

# Baixar arquivos de zona
wget https://www.internic.net/domain/named.root -O "$UNBOUND_ROOT_HINTS" || _MSG_ERRO_INFO 'Erro ao baixar arquivo root.hints'
chown unbound:unbound "$UNBOUND_ROOT_HINTS" || _MSG_ERRO_INFO "Erro ao acessar arquivo $UNBOUND_ROOT_HINTS" 

wget http://www.internic.net/domain/root.zone   -O "$UNBOUND_ROOT_ZONES" || _MSG_ERRO_INFO 'Erro ao baixar arquivo root.hints'
chown unbound:unbound "$UNBOUND_ROOT_ZONES" || _MSG_ERRO_INFO 'Erro ao acessar arquivo root.zone'

# Arquivo root key
ROOT_KEY=$(find /etc/ -iname root.key)
ROOT_KEY=${ROOT_KEY:=/etc/unbound/root.key}

# Função não implementada
#[[ -f "$ROOT_KEY" ]] && rm -rf "$ROOT_KEY"
#unbound-anchor -a "$ROOT_KEY" -vvv
#chown unbound:unbound "$ROOT_KEY"

## Erro aqui

# Realizar backup do arquivo padrão de configuração
UNBOUND_CONF=$(find /etc/ -iname unbound.conf) || _MSG_ERRO_INFO 'Arquivo não encontrado'
[[ ! -e "$UNBOUND_CONF".orig ]] && cp "$UNBOUND_CONF"{,.orig}

# Numero de cores
NCORE=$(nproc)
CACHE=$(echo "scale=2; $(nproc)^3" | bc) || _MSG_ERRO_INFO 'Erro ao realizar opeção'

MEM=$(free -m | grep -i mem | awk '{print $2}')
# Usar 10 %
MIN_MEM=$(echo "scale=2; $MEM * 0.1" | bc) || _MSG_ERRO_INFO 'Erro ao realizar opeção'
# Usar 50%
MAX_MEM=$(echo "scale=2; $MEM * 0.5" | bc) || _MSG_ERRO_INFO 'Erro ao realizar opeção'

# Gravar arquivo
cat > "$UNBOUND_CONF" << EOF
server:
        verbosity: 1
        log-queries: yes
	chroot: ""
 
        # interface-automatic: no
        do-udp: yes
        do-tcp: yes
        do-ip4: yes
        do-ip6: no
        interface: 127.0.0.1
        interface: $IP_UNBOUND
        port: 53
        prefetch: yes

        tls-cert-bundle: /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
        root-hints: $UNBOUND_ROOT_HINTS

        cache-max-ttl: 14400
        cache-min-ttl: 1200
        
        #control which clients are allowed to make (recursive) queries
        access-control: 127.0.0.1/32 allow_snoop
        access-control: ::1 allow_snoop
        access-control: 127.0.0.0/8 allow
        access-control: $IP_UNBOUND/$MASK allow
        so-rcvbuf: 8m

#DNSSEC
#        auto-trust-anchor-file: "$ROOT_KEY"

#[ privacidade ]
        hide-identity: yes
        hide-version: yes
        harden-glue: yes
        harden-dnssec-stripped: yes
        use-caps-for-id: yes
        val-clean-additional: yes
        unwanted-reply-threshold: 10000
        private-address: 10.0.0.0/8
        private-address: 100.64.0.0/10
        private-address: 127.0.0.0/8
        private-address: 172.16.0.0/12
        private-address: 192.168.0.0/16
        private-address: 169.254.0.0/16
        private-address: fd00::/8
        private-address: fe80::/10
        private-address: ::ffff:0:0/96

#[ performance ]
        num-threads: $NCORE
        msg-cache-slabs: $CACHE
        key-cache-slabs: $CACHE
        rrset-cache-slabs: $CACHE
        infra-cache-slabs: $CACHE
        rrset-roundrobin: yes
        rrset-cache-size: ${MIN_MEM//.*}m
        msg-cache-size: ${MAX_MEM//.*}m
        cache-max-ttl: 86400
        outgoing-num-tcp: 1024
        outgoing-range: 8192
        num-queries-per-thread: 4096
        so-reuseport: yes
        prefetch: yes
        prefetch-key: yes

# Segurança
unwanted-reply-threshold: 10000
do-not-query-localhost:no
val-clean-additional: yes

# Bloqueios de dominios, bloco composto de local-zone e local-data
local-zone: "doubleclick.net" redirect
local-data: "doubleclick.net A 127.0.0.1"

auth-zone:
	name: "."
        fallback-enabled: yes
        for-downstream: no
        for-upstream: yes
        zonefile: "$UNBOUND_ROOT_ZONES"

# FIM
EOF

# Adicionar serviço ao firewall
firewall-cmd --state | grep -qi running && { firewall-cmd --add-service=dns --permanent || _MSG_ERRO_INFO 'Erro ao adicionar serviço DNS' ; }
firewall-cmd --state | grep -qi running && { firewall-cmd --reload                      || _MSG_ERRO_INFO 'Erro ao reiniciar firewalld' ; }

# Reiniciar serviço DNS
systemctl restart unbound || _MSG_ERRO_INFO 'Serviço não inicializado'
systemctl enable unbound  || _MSG_ERRO_INFO 'Erro ao inicializar serviço'

# Verificar sistema e serviços precisa de restart
for services in $(needs-restarting -s) ; do systemctl restart "$services" ; done
needs-restarting -r > /dev/null || { if whiptail --title "Aplicar Configurações - Unbound" --yesno "Deseja reiniciar o servidor" 10 50 --defaultno ; then reboot ; fi ; } 

# Fim do script
