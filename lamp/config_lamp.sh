#!/bin/bash
# ==============================================================================
# Script de Automatización - Instalación, Red y Configuración de Servidor LAMP
# Interfaz de Red: ens192
# ==============================================================================

set -e

# Verificación de privilegios de root
if [ "$EUID" -ne 0 ]; then
  echo "Error: Este script debe ejecutarse con privilegios de root (sudo)."
  exit 1
fi

echo "=================================================================="
echo "Iniciando Despliegue Automatizado del Servidor LAMP..."
echo "=================================================================="

# 1. Configuración de IP Estática manual en ens192
echo "[1/6] Configurando IP Estática (192.168.50.12/24) en ens192..."
nmcli connection modify "ens192" ipv4.addresses 192.168.50.12/24 ipv4.method manual
nmcli connection up "ens192"
echo "IP Estática 192.168.50.12 configurada correctamente en ens192."

# 2. Instalación de paquetes LAMP
echo "[2/6] Actualizando repositorios e instalando Apache, MariaDB y PHP..."
dnf update -y
dnf install -y httpd mariadb-server mariadb php php-mysqlnd php-fpm

# 3. Habilitación e inicio de servicios
echo "[3/6] Habilitando e iniciando servicios HTTPD y MariaDB..."
systemctl enable --now httpd
systemctl enable --now mariadb

# 4. Configuración del Firewall
echo "[4/6] Configurando reglas del cortafuegos (Puertos 80 y 443)..."
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

# 5. Generación de la página Web
echo "[5/6] Creando la página web principal (/var/www/html/index.html)..."
cat << 'EOF' > /var/www/html/index.html
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Proyecto Final - Servidor LAMP</title>
    <style>
        body {
            font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            background-color: #f0f2f5;
            color: #1c1e21;
            margin: 0;
            padding: 40px 20px;
            display: flex;
            justify-content: center;
        }
        .card {
            background: #ffffff;
            padding: 35px;
            border-radius: 12px;
            box-shadow: 0 8px 24px rgba(0, 0, 0, 0.08);
            max-width: 650px;
            width: 100%;
        }
        .header {
            text-align: center;
            border-bottom: 2px solid #0d6efd;
            padding-bottom: 15px;
            margin-bottom: 25px;
        }
        h1 {
            color: #0d6efd;
            margin: 0 0 5px 0;
            font-size: 1.8em;
        }
        h2 {
            color: #495057;
            font-size: 1.1em;
            margin: 0;
            font-weight: 500;
        }
        .status-box {
            background-color: #d1e7dd;
            color: #0f5132;
            padding: 12px 20px;
            border-radius: 8px;
            text-align: center;
            font-weight: 600;
            margin-bottom: 30px;
            border: 1px solid #badbcc;
        }
        .members-title {
            color: #212529;
            font-size: 1.2em;
            margin-bottom: 15px;
            font-weight: 600;
        }
        .member-list {
            display: flex;
            flex-direction: column;
            gap: 12px;
        }
        .member-card {
            display: flex;
            align-items: center;
            background: #f8f9fa;
            padding: 12px 16px;
            border-radius: 8px;
            border: 1px solid #e9ecef;
        }
        .avatar {
            width: 48px;
            height: 48px;
            border-radius: 50%;
            color: white;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: bold;
            font-size: 1.1em;
            margin-right: 15px;
            flex-shrink: 0;
        }
        .member-info h4 {
            margin: 0;
            color: #212529;
            font-size: 1em;
        }
        .member-info p {
            margin: 3px 0 0 0;
            color: #6c757d;
            font-size: 0.88em;
        }
        .footer {
            margin-top: 30px;
            text-align: center;
            font-size: 0.85em;
            color: #6c757d;
            border-top: 1px solid #dee2e6;
            padding-top: 15px;
        }
    </style>
</head>
<body>
    <div class="card">
        <div class="header">
            <h1>Sistemas Operativos I</h1>
            <h2>Proyecto Final - Servidor Web LAMP (CentOS Stream 9)</h2>
        </div>

        <div class="status-box">
            ✓ Servidor Web Apache, PHP y MySQL/MariaDB Activo
        </div>

        <div class="members-title">Integrantes del Grupo:</div>

        <div class="member-list">
            <div class="member-card">
                <div class="avatar" style="background-color: #0d6efd;">DC</div>
                <div class="member-info">
                    <h4>Diego Estefan Cuellar Fortín</h4>
                    <p>N° de Cuenta: 20231002887</p>
                </div>
            </div>

            <div class="member-card">
                <div class="avatar" style="background-color: #6f42c1;">FS</div>
                <div class="member-info">
                    <h4>Fernando Antonio Solórzano Vásquez</h4>
                    <p>N° de Cuenta: 20241031518</p>
                </div>
            </div>

            <div class="member-card">
                <div class="avatar" style="background-color: #198754;">AH</div>
                <div class="member-info">
                    <h4>Andoni Oniel Hernández Portillo</h4>
                    <p>N° de Cuenta: 20241030166</p>
                </div>
            </div>

            <div class="member-card">
                <div class="avatar" style="background-color: #fd7e14;">JC</div>
                <div class="member-info">
                    <h4>Johan Samuel Cuellar Fortín</h4>
                    <p>N° de Cuenta: 20231002889</p>
                </div>
            </div>
        </div>

        <div class="footer">
            Servicio Web Alojado en CentOS Stream 9 | Puerto 80 (HTTP) | Dominio: centos.hn
        </div>
    </div>
</body>
</html>
EOF

# 6. Asignación de Permisos y Propietario
echo "[6/6] Ajustando permisos de lectura y propietario para Apache..."
chmod 644 /var/www/html/index.html
chown apache:apache /var/www/html/index.html

echo "=================================================================="
echo "  Despliegue Finalizado Exitosamente"
echo "=================================================================="
