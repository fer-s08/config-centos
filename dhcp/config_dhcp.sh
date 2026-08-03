#!/bin/bash
# ==============================================================================
# SCRIPT COMPLETO: CONFIGURACIÓN DE RED E INSTALACIÓN DE SERVIDOR DHCP
# Interfaz: ens192        | IP Servidor: 192.168.50.10/24
# Dominio: centos.hn      | Servidor DNS: 192.168.50.11
# ==============================================================================


if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script usando sudo o como usuario root."
  exit 1
fi

echo "1. Configurando tarjeta de red privada (ens192)..."
nmcli con mod ens192 ipv4.method manual \
    ipv4.addresses 192.168.50.10/24 \
    ipv4.gateway 192.168.50.1 \
    ipv4.dns 192.168.50.11 \
    ipv4.dns-search "centos.hn"

nmcli con up ens192
echo "[✓]Interfaz ens192 configurada con IP 192.168.50.10."

echo "2. Instalando el paquete dhcp-server mediante dnf..."
dnf install -y dhcp-server

echo "3. Generando el archivo de configuración /etc/dhcp/dhcpd.conf..."
cat <<EOF > /etc/dhcp/dhcpd.conf

option domain-name "centos.hn";
option domain-name-servers 192.168.50.11;

default-lease-time 600;
max-lease-time 7200;
authoritative;

# Subred Privada Virtual
subnet 192.168.50.0 netmask 255.255.255.0 {
    range 192.168.50.50 192.168.50.100;
    option routers 192.168.50.1;
    option subnet-mask 255.255.255.0;
    option broadcast-address 192.168.50.255;
    option domain-name-servers 192.168.50.11;
}
EOF
echo "[✓] Archivo dhcpd.conf creado."

echo "4. Excluyendo la interfaz NAT y asignando DHCP exclusivamente a ens192..."
echo 'DHCPDARGS=ens192' > /etc/sysconfig/dhcpd

echo "5. Permitiendo tráfico DHCP en el Firewall..."
firewall-cmd --permanent --add-service=dhcp
firewall-cmd --reload

echo "6. Habilitando e iniciando el demonio dhcpd..."
systemctl enable --now dhcpd

echo "7. Comprobando el estado del servicio:"
systemctl status dhcpd --no-pager
