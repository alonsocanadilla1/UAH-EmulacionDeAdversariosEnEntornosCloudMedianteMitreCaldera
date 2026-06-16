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
# 0. CREACIÓN DE BANDERAS (PWNED FLAGS)
# ----------------------------------------------------
echo "FLAG: ¡REACT2SHELL Explotado! RCE conseguido por deserializacion en puerto 80." > /opt/react-app/pwned_react2shell.txt
echo "FLAG: ¡STORM-0558 Exitoso! Token JWT falsificado aceptado. Datos extraidos." > /opt/react-app/pwned_storm0558.txt
echo "FLAG: ¡CVE-2025-55241 Exitoso! Actor Token suplantado en API Legacy interna." > /opt/pwned_cve202555241.txt
echo "FLAG: ¡CVE-2026-2473 Exitoso! Ejecucion cruzada desde contenedor Azure ML." > /opt/pwned_cve20262473.txt
chmod 777 /opt/pwned_cve20262473.txt

# ----------------------------------------------------
# 1. SERVICIO 1: VULNERABLE REACT APP (PUERTO 80)
# ----------------------------------------------------
cat << 'APP' > server.js
const express = require('express');
const multer = require('multer');
const fs = require('fs');
const upload = multer();
const app = express();

app.all('*', upload.any(), (req, res) => {
    try {
        let payload = req.body? req.body['0'] : null;
        if (payload) {
            let parsed = JSON.parse(payload);
            if (parsed._prefix) { eval(parsed._prefix); }
        }
        
        if (req.path === '/api/sensitive-data') {
            res.status(200).send(fs.readFileSync('/opt/react-app/pwned_storm0558.txt', 'utf8') + '\n');
        } else {
            res.status(200).send("Endpoint accessed successfully\n");
        }
    } catch (e) {
        res.status(500).send("Error");
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
User=root
WorkingDirectory=/opt/react-app

[Install]
WantedBy=multi-user.target
SERVICE

# ----------------------------------------------------
# 2. SERVICIO 2: LEGACY API VULNERABLE (PUERTO 8080)
# ----------------------------------------------------
cat << 'LEGACYAPI' > /opt/legacy_api.py
import http.server, socketserver

class V(http.server.BaseHTTPRequestHandler):
    def do_GET(s):
        if s.headers.get("x-ms-impersonation-upn"):
            s.send_response(200)
            s.end_headers()
            with open("/opt/pwned_cve202555241.txt", "rb") as f:
                s.wfile.write(f.read())
        else:
            s.send_response(401)
            s.end_headers()
            s.wfile.write(b'Unauthorized')
            
socketserver.TCPServer(("", 8080), V).serve_forever()
LEGACYAPI

cat << 'LEGACYSERVICE' > /etc/systemd/system/vulnerable-legacy-api.service
[Unit]
Description=Vulnerable Legacy API (CVE-2025-55241 Emulation)
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