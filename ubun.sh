#!/usr/bin/env bash
set -e

# ——— Configuración inicial ———
DOMINIO="konohalinks.duckdns.org"
EMAIL="christiandg1308@gmail.com"
REPO_URL="https://github.com/ChristianDGF/parcial-3.git"
APP_DIR="$HOME/parcial-3"

# (Si aún no lo has hecho) Conéctate al servidor:
# ssh -i e3.pem ubuntu@3.236.30.6

# ——— 1. Crear swap ———
sudo dd if=/dev/zero of=/swapfile count=2048 bs=1MiB
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# ——— 2. Instalar paquetes base ———
sudo apt update
sudo apt -y install apache2 certbot python3-certbot-apache unzip zip curl

# ——— 3. Habilitar módulos en Apache ———
sudo a2enmod ssl proxy proxy_http
sudo systemctl restart apache2

# ——— 4. Instalar SDKMAN y Java 21 ———
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java 21.0.3-tem

# ——— 5. Clonar repositorio de la aplicación ———
git clone "$REPO_URL" "$APP_DIR"
cd "$APP_DIR"

# ——— 6. Generar certificado SSL ANTES de crear el VirtualHost ———
sudo systemctl stop apache2
sudo certbot certonly --standalone \
  --non-interactive --agree-tos \
  -m "$EMAIL" \
  -d "$DOMINIO"
sudo systemctl start apache2

# ——— 7. Crear la configuración de Apache ———
sudo tee /etc/apache2/sites-available/seguro.conf > /dev/null << EOF
<VirtualHost *:80>
    ServerName $DOMINIO
    Redirect permanent / https://$DOMINIO
</VirtualHost>

<VirtualHost *:443>
    ServerName $DOMINIO

    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/$DOMINIO/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/$DOMINIO/privkey.pem

    ProxyPass / http://localhost:7000/
    ProxyPassReverse / http://localhost:7000/

    <Directory "/var/www/html">
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

# ——— 8. Habilitar sitio y recargar Apache ———
sudo a2ensite seguro.conf
sudo apachectl configtest   # Debe devolver "Syntax OK"
sudo systemctl reload apache2

# ——— 9. Construir y arrancar la aplicación ———
chmod +x gradlew
./gradlew shadowjar
nohup java -jar "$APP_DIR/build/libs/app.jar" \
  > "$APP_DIR/build/libs/salida.txt" \
  2> "$APP_DIR/build/libs/error.txt" &

# ——— 10. Verificaciones y firewall ———
ps aux | grep app.jar
curl -I http://localhost:7000

sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 7000
sudo ufw --force enable

echo "¡Despliegue completado! ✔️"