#!/bin/bash

# Actualizacion del sistema
sudo dnf update -y && sudo dnf upgrade -y

# Instalaciones de los paquetes necesarios para configurar el servicio
sudo dnf install bind bind-utils -y

# Configuracion de la red de la maquina virtual, por medio de NetworkManager
nmcli device show

echo "Seleccion de la interfaz de red a configurar"

interface=""
flag=true
while $flag; do
    echo "INTERFAZ DE RED"
    echo "1. ens160"
    echo "2. ens192"
    echo "0. Cancelar"
    echo -n "Escoja una opcion: "
    read -r opcion

    case $opcion in
        1)
            interface=ens160
            flag=false
            ;;
        2)  interface=ens192
            flag=false
            ;;
        0)
            echo "Cerrando script..."
            exit 0
            ;;
        *)
            echo "Opcion no valida"
            ;;
    esac

    echo "La interfaz seleccionada fue: $interface"
done

DIRECCION_IP=192.168.50.11
GATEWAY=192.168.50.1
SUBNET=192.168.50.0/24
DOMINIO=centos.hn

# Una vez seleccionada la interfaz de red, se aplican los comandos sobre esta, utilizando nmcli
nmcli con mod $interface ipv4.method manual ipv4.addr "$DIRECCION_IP/24" ipv4.gateway $GATEWAY ipv4.dns $DIRECCION_IP ipv4.dns-search "$DOMINIO"
nmcli con down $interface; nmcli con up $interface

# Configuracion del archivo named.conf
sudo sed -i 's\listen-on port 53 { 127.0.0.1; };\listen-on port 53 { 127.0.0.1; 192.168.50.0/24; };\' /etc/named.conf
sudo sed -i 's\listen-on-v6 port 53 { ::1; };\listen-on-v6 port 53 { none; };\' /etc/named.conf
sudo sed -i 's\allow-query     { localhost; };\allow-query { localhost; 192.168.50.0/24; };\' /etc/named.conf

# Validacion para comprobar si la configuracion de las zonas ya habia sido declarada en named.conf
# Se agregan las zonas de busqueda directa e indirecta
if grep -q -F "centos.hn" /etc/named.conf ; then
    echo "La zona centos.hn ya fue configurada en este archivo"
else 
    sudo tee -a /etc/named.conf << 'EOF'
        zone "centos.hn" IN {
            type master;
            file "/var/named/named.centos.hn";
            allow-update { none; };
        };
EOF
fi

if grep -q -F "50.168.192.in-addr.arpa" /etc/named.conf ; then
    echo "La zona 50.168.192 ya fue configurada en este archivo"
else
    sudo tee -a /etc/named.conf << 'EOF'
        zone "50.168.192.in-addr.arpa" IN {
            type master;
            file "/var/named/named.50.168.192";
            allow-update { none; };
        };
EOF
fi

echo "Comprobacion de la configuracion..."
sudo named-checkzone

# Configuracion de los archivos de zona
# ======= Archivo de zona directa======
if [ -e /var/named/named.centos.hn ]; then
    echo "El archivo de zona directa ya fue creado"
else
    sudo tee /var/named/named.centos.hn << 'EOF'
        $TTL 86400
        @   IN  SOA servidor.centos.hn. root.centos.hn. (
            2026080402  ;Serial
            3600    ;Refresh
            1800    ;Retry
            604800  ;Expire
            86400   ;Minimum TTL
        )
                    IN  NS  servidor.centos.hn.
        servidor    IN  A   192.168.50.11
        router      IN  A   192.68.50.1
        server      IN  CNAME   servidor
        www         IN  CNAME   servidor
        correo      IN  A   192.168.50.11
        centos.hn   IN  MX 10   correo
EOF
fi

# ===== Archivo de zona inversa =====
if [ -e /var/named/named.50.168.192 ]; then
    echo "El archivo de zona inversa ya existe"
else
    sudo tee /var/named/named.50.168.192 << 'EOF'
        $TTL 86400
        @   IN  SOA servidor.centos.hn. root.centos.hn. (
            2026080401  ;Serial
            3600    ;Refresh
            1800    ;Retry
            604800  ;Expire
            86400   ;Minimum TTL
        )
                IN  NS  servidor.centos.hn.
        11      IN  PTR servidor.centos.hn.
        50      IN  PTR router.centos.hn.
        11      IN  PTR correo.centos.hn.
EOF
fi

# Configuracion de permisos
sudo chown root:named /var/named/named.centos.hn /var/named/named.50.168.192
sudo chroot 640 /var/named/named.centos.hn /var/named/named.50.168.192

# Configuracion para aceptar unicamente conexiones IPV4
echo "OPTIONS=-4" | sudo tee -a /etc/sysconfig/named

# Configuracion de firewalld para permitir el servicio de DNS
sudo firewall-cmd --add-service=dns

# Validacion para comprobar el estado del firewall
FIREWALLD_STATUS=$(systemctl is-active firewalld)

# Si el servicio ya esta activo, entonces solamente lo reinicia
if [ "$FIREWALLD_STATUS" = "active"]; then
    sudo systemctl restart firewalld
# Si el servicio fallo, muestra un mensaje en pantalla
elif [ "$FIREWALLD_STATUS" = "failed" ]; then
    echo "Fallo al iniciar el servicio Firewalld"
# En otro caso, se considera que el servicio esta deshabilitado pero no debido a un error
# En este caso, se habilita y se inicia a la vez
else
    sudo systemctl enable --now firewalld
fi

NAMED_STATUS=$(systemctl is-active named)

# De forma similar a firewalld, se realizan las mismas validaciones al servicio named
if [ "$NAMED_STATUS" = "active" ]; then
    sudo systemctl restart named
elif [ "$NAMED_STATUS" = "failed "]; then
    echo "Hubo un error al iniciar el servicio Named"
    systemctl status named
else 
    systemctl enable --now named
fi