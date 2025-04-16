#!/usr/bin/env bash
echo "Instalando estructura basica para clase virtualhost y proxy reverso"

# Habilitando la memoria de intercambio.
sudo dd if=/dev/zero of=/swapfile count=2048 bs=1MiB
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
sudo cp /etc/fstab /etc/fstab.bak
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Instalando los software necesarios
sudo apt update && sudo apt -y install apache2 certbot python3-certbot-apache unzip zip
sudo a2enmod ssl
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo systemctl restart apache2

# Instalando sdkman y Java
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java 21.0.3-tem

# Subiendo el servicio de Apache
sudo service apache2 start

# Clonando el proyecto
cd ~/
git clone https://github.com/ChristianDGF/apache.git
cd ~/apache/proyecto

# Configuración de VirtualHost
sudo bash -c 'cat > /etc/apache2/sites-available/seguro.conf << EOF
<VirtualHost *:80>
    ServerName app.christiangutierrez.tech
    Redirect permanent / https://app.christiangutierrez.tech
</VirtualHost>

<VirtualHost *:443>
    ServerName app.christiangutierrez.tech

    DocumentRoot /var/www/html

    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/app.christiangutierrez.tech/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/app.christiangutierrez.tech/privkey.pem

    ProxyPass / http://localhost:7000/
    ProxyPassReverse / http://localhost:7000/

    <Directory "/var/www/html">
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF'

sudo a2ensite seguro.conf
sudo systemctl reload apache2

# Certificado SSL
DOMINIO="app.christiangutierrez.tech"
EMAIL="christiandg1308@gmail.com"

sudo systemctl stop apache2
if [ ! -f "/etc/letsencrypt/live/$DOMINIO/cert.pem" ]; then
    echo "Generando certificado SSL para $DOMINIO..."
    sudo certbot certonly --standalone -m $EMAIL -d $DOMINIO --agree-tos --non-interactive
else
    echo "Certificado para $DOMINIO ya existe."
fi
sudo systemctl start apache2

cd ~/ApacheReady/proyecto-final
chmod +x gradlew

# 🔹 Ejecutar creación del fat JAR con la variable de entorno
export MONGODB_URL="mongodb+srv://christiandg1308:VOoGg1gGvu3KWwNm@cluster0.dobb5qz.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0"
./gradlew shadowjar

# 🔹 Iniciar la app en segundo plano con la variable de entorno
nohup env MONGODB_URL="mongodb+srv://christiandg1308:VOoGg1gGvu3KWwNm@cluster0.dobb5qz.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0" \
     java -jar build/libs/app.jar > build/libs/salida.txt 2> build/libs/error.txt &

# 🔹 Asegurar puerto 50051 esté accesible (gRPC)
echo "Asegurando acceso al puerto 9090 para gRPC..."
sudo ufw allow 9090/tcp  # O equivalente para tu entorno si no usas UFW#!/usr/bin/env bash