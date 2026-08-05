#!/bin/bash

# Actualizacion del sistema
sudo dnf update -y && sudo dnf upgrade -y

# Instalaciones de los paquetes necesarios para configurar el servicio
sudo dnf install bind bind-utils -y

# Configuracion de la red de la maquina virtual, por medio de NetworkManager
nmcli device show

echo "Seleccion de la interfaz de red a configurar"

interface=""
while true; do
    echo "INTERFAZ DE RED"
    echo "1. ens160"
    echo "2. ens192"
    echo "0. Cancelar"
    echo -n "Escoja una opcion: "
    read -r opcion

    case $opcion in
        1)
            $interface=ens160
            return
            ;;
        2)  $interface=ens192
            return
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
DOMINIO=centos.hn

# Una vez seleccionada la interfaz de red, se aplican los comandos sobre esta, utilizando nmcli
nmcli con mod $interface ipv4.method manual ipv4.addr "${DIRECCION_IP}/24" ipv4.gateway $GATEWAY ipv4.dns $DIRECCION_IP ipv4.dns-search "${DOMINIO}"
nmcli con down $interface; nmcli con up $interface

# Configuracion del archivo named.conf
sudo sed -i 's\listen-on port 53 { 127.0.0.1; };\listen-on port 53 { 127.0.0.1; 192.168.50.0/24; };\' /etc/named.conf
sudo sed -i 's\listen-on-v6 port 53 { ::1; };\listen-on-v6 port 53 { none; };\' /etc/named.conf
sudo sed -i 's\allow-query     { localhost; };\allow-query { localhost; 192.168.50.0/24; };\' /etc/named.conf

# Se agregan las zonas de busqueda directa e indirecta
sudo tee -a /etc/named.conf > /dev/null <<EOT
zone "centos.hn" IN {
    type master;
    file "/var/named/named.centos.hn";
    allow-update { none; };
};

zone "50.168.192.in-addr.arpa" IN {
    type master;
    file "/var/named/named.50.168.192";
    allow-update { none; };
};
EOT

echo "Comprobacion de la configuracion..."
sudo named-checkzone

# Configuracion de los archivos de zona
sudo tee -a /var/named/named.centos.hn > /dev/null <<EOT
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
router      IN  A   192.168.50.1
server      IN  CNAME   servidor
www         IN  CNAME   servidor
correo      IN  A   192.168.50.11
centos.hn   IN  MX 10   correo
EOT

sudo tee -a /var/named/named.50.168.192 > /dev/null <<EOT
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
EOT

# Configuracion de permisos
sudo chown root:named /var/named/named.centos.hn /var/named/named.50.168.192
sudo chroot 640 /var/named/named.centos.hn /var/named/named.50.168.192

# Configuracion para aceptar unicamente conexiones IPV4
echo "OPTIONS=-4" | sudo tee -a /etc/sysconfig/named > /dev/null

# Configuracion de firewalld para permitir el servicio de DNS
sudo firewall-cmd --add-service=dns

# Listar los servicios agregados en el firewall
sudo firewall-cmd --list-all
sleep 2

# Configuracion y habilitacion del servicio named
sudo systemctl enable --now named
systemctl status named
sleep 2

echo "Se ha configurado el servicio de DNS correctamente!"
exit 0