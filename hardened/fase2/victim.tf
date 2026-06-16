resource "azurerm_public_ip" "pip_web_victim" {
  name                = "pip-web-victim"
  location            = azurerm_resource_group.tfg_rg.location
  resource_group_name = azurerm_resource_group.tfg_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic_web_victim" {
  name                = "nic-web-victim"
  location            = azurerm_resource_group.tfg_rg.location
  resource_group_name = azurerm_resource_group.tfg_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.dmz_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.2.4"
    public_ip_address_id          = azurerm_public_ip.pip_web_victim.id
  }
}

resource "azurerm_linux_virtual_machine" "web_victim" {
  name                  = "vm-web-victim"
  resource_group_name   = azurerm_resource_group.tfg_rg.name
  location              = azurerm_resource_group.tfg_rg.location
  size                  = "Standard_D2s_v3"
  admin_username        = "tfgadmin"

  network_interface_ids = [ azurerm_network_interface.nic_web_victim.id ]

  admin_ssh_key {
    username   = "tfgadmin"
    public_key = file("~/.ssh/id_rsa.pub") 
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOF
#!/bin/bash
apt-get update -y
apt-get install -y curl ca-certificates gnupg python3
curl -sL https://aka.ms/InstallAzureCLIDeb | bash
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
mkdir -p /opt/react-app
cd /opt/react-app
npm init -y
npm install express@4 multer

# ----------------------------------------------------
# 0. CREACIÓN DE BANDERAS Y HARDENING (ETAPA 1)
# ----------------------------------------------------
# Aislamiento de OS para React2Shell
useradd -rs /bin/false reactapp
chown -R reactapp:reactapp /opt/react-app

echo "FLAG: ¡REACT2SHELL Explotado!" > /opt/react-app/pwned_react2shell.txt
chown root:root /opt/react-app/pwned_react2shell.txt
chmod 400 /opt/react-app/pwned_react2shell.txt

echo "FLAG: ¡STORM-0558 Exitoso! Token JWT falsificado aceptado. Datos extraidos." > /opt/react-app/pwned_storm0558.txt
echo "FLAG: ¡CVE-2025-55241 Exitoso! Actor Token suplantado en API Legacy interna." > /opt/pwned_cve202555241.txt
echo "FLAG: ¡CVE-2026-2473 Exitoso! Ejecucion cruzada desde contenedor Azure ML." > /opt/pwned_cve20262473.txt
chmod 777 /opt/pwned_cve20262473.txt

# ----------------------------------------------------
# 1. SERVICIO 1: REACT APP (Hardening STORM-0558 Fase 1)
# ----------------------------------------------------
cat << 'APP' > /opt/react-app/server.js
const express = require('express');
const multer = require('multer');
const fs = require('fs');
const upload = multer();
const app = express();

app.all('*', upload.any(), (req, res) => {
    if (JSON.stringify(req.body || {}).includes('__proto__')) {
        return res.status(403).send("Inyeccion de prototipo detectada y bloqueada por WAF (HARDENING FASE 2).\n");
    }
    try {
        let payload = req.body ? req.body['0'] : null;
        if (payload) {
            let parsed = JSON.parse(payload);
            if (parsed._prefix) { eval(parsed._prefix); }
        }
        
        if (req.path === '/api/sensitive-data') {
            const authHeader = req.headers['authorization'] || '';
            // HARDENING FASE 1: Extraemos y decodificamos el payload del JWT (Parte central)
            try {
                const tokenPayload = Buffer.from(authHeader.split('.')[1], 'base64').toString('utf-8');
                // Bloqueo de la Clave Consumidor Cruzada
                //if (tokenPayload.includes('9188040d-6c67-4c5b-b112-36a304b66dad')) {
                //    return res.status(401).send("VALIDACIÓN ESTRICTA: Clave de consumidor entre inquilinos (Cross-Tenant) rechazada para datos empresariales (HARDENING FASE 1).\n");
                //}
                // HARDENING FASE 2: Validación estricta del Issuer
            	const parsedPayload = JSON.parse(tokenPayload);
            	if (parsedPayload.iss === 'https://login.microsoftonline.com/9188040d-6c67-4c5b-b112-36a304b66dad/v2.0' || parsedPayload.upn === 'admin@__TENANT_DOMAIN__') 
                {
                    return res.status(401).send("Token Issuer no coincide con la raiz de confianza corporativa (HARDENING FASE 2).\n");
                }
            } catch(e) {}
            
            res.status(200).send(fs.readFileSync('/opt/react-app/pwned_storm0558.txt', 'utf8') + '\n');
        } else {
            res.status(200).send("Endpoint accessed successfully\n");
        }
    } catch (e) {
        res.status(500).send("System Error: " + e.message + "\n");
    }
});
app.listen(80, '0.0.0.0');
APP

cat << 'SERVICE' > /etc/systemd/system/vulnerable-react.service
[Unit]
Description=Vulnerable React RSC Service (React2Shell PoC)
After=network.target

[Service]
ExecStart=/usr/bin/node /opt/react-app/server.js
Restart=always
# HARDENING: Ejecución con privilegios reducidos (Aislamiento OS)
User=reactapp
WorkingDirectory=/opt/react-app
# Permite enlazar el puerto 80 sin ser root
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
SERVICE

# ----------------------------------------------------
# 2. SERVICIO 2: LEGACY API
# ----------------------------------------------------
pip3 install PyJWT cryptography -q

cat << 'LEGACYAPI' > /opt/legacy_api.py
import http.server, socketserver

# ====================================================================
# HARDENING FASE 1
# ====================================================================
import base64
class V(http.server.BaseHTTPRequestHandler):
    def do_GET(s):
        auth_header = s.headers.get("Authorization", "")
        
        # HARDENING FASE 1: Decodificamos Base64Url para detectar la firma falsa HS256
        try:
            if auth_header.startswith("Bearer "):
                token = auth_header.split(" ")[1]
                header_b64 = token.split(".")[0] + "=="
                header_decoded = base64.urlsafe_b64decode(header_b64).decode('utf-8')
                
                if "HS256" in header_decoded:
                    s.send_response(401)
                    s.end_headers()
                    s.wfile.write(b'La API ha bloqueado el token falso (HARDENING FASE 1).\n')
                    return
        except Exception:
            pass
             
        if s.headers.get("x-ms-impersonation-upn"):
            s.send_response(200)
            s.end_headers()
            with open("/opt/pwned_cve202555241.txt", "rb") as f:
                s.wfile.write(f.read())
        else:
            s.send_response(401)
            s.end_headers()
            s.wfile.write(b'Unauthorized\n')
             
socketserver.TCPServer(("", 8080), V).serve_forever()

LEGACYAPI

cat << 'LEGACYSERVICE' > /etc/systemd/system/vulnerable-legacy-api.service
[Unit]
Description=Vulnerable React RSC Service (React2Shell PoC)
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/legacy_api.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
LEGACYSERVICE

# ----------------------------------------------------
# 3. RECARGA Y ACTIVACIÓN DE SERVICIOS
# ----------------------------------------------------
systemctl daemon-reload
systemctl enable --now vulnerable-react.service
systemctl enable --now vulnerable-legacy-api.service
EOF
  )

    identity {
        type         = "SystemAssigned, UserAssigned"
        identity_ids = [ azurerm_user_assigned_identity.admin_identity.id ]
    }
}