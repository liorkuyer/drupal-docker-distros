#!/bin/sh
# Custom script to install software on the server. Run with 'sudo'.
# Change variables according to your neeeds

DOMAIN="distros.bid"
SUBDOMAIN="drupal.distros.bid"
NGINXPORT="8055"

INSTALL_RANCHER=0
INSTALL_PORTAINER=1
INSTALL_CADVISOR=0
INSTALL_ADMIRAL=0

# Monitoring system ports from 9988 - 9989
PORTAINERPORT="9988"
RANCHERPORT="9989"
CADVISORPORT="9990"
ADMIRALPORT="9991"

# Generic software
apt-get -qqy update
apt-get install -y --force-yes git wget vim zip apache2 php7.0 php7.0-mbstring

# Composer
wget -q https://github.com/composer/composer/releases/download/1.4.2/composer.phar
chmod +x composer.phar && \
mv composer.phar /usr/local/bin/composer

# Clone git files
rm -rf /var/www/html
git clone https://github.com/theodorosploumis/drupal-docker-distros.git /var/www/distros/

# Docker. Notice that we do not install latest Docker to support Rancher
# curl https://get.docker.com | sh
curl https://releases.rancher.com/install-docker/17.06.sh | sh

# Start nginx-proxy on port $NGINXPORT
docker run -d -p ${NGINXPORT}:80 \
       --name proxy \
       --restart=unless-stopped \
       -v /var/run/docker.sock:/tmp/docker.sock:ro \
       jwilder/nginx-proxy

# Add www-data to group docker
usermod -aG docker www-data

# Start Portainer dashboard
if [ "${INSTALL_PORTAINER}" -eq "1" ]; then
docker volume create portainer_data
docker run -d -p ${PORTAINERPORT}:9000 \
       -v /var/run/docker.sock:/var/run/docker.sock \
       -v portainer_data:/data \
       --name=portainer \
       portainer/portainer
fi

# Start rancher dashboard
if [ "${INSTALL_RANCHER}" -eq "1" ]; then
docker run -d --name=rancher_server \
       --restart=unless-stopped \
       -p ${RANCHERPORT}:8080 \
       rancher/server:stable
fi

# Start cAdvisor dashboard
if [ "${INSTALL_CADVISOR}" -eq "1" ]; then
   docker run \
          --volume=/:/rootfs:ro \
          --volume=/var/run:/var/run:rw \
          --volume=/sys:/sys:ro \
          --volume=/var/lib/docker/:/var/lib/docker:ro \
          --volume=/dev/disk/:/dev/disk:ro \
          --publish=${CADVISORPORT}:8080 \
          --detach=true \
          --name=cadvisor \
          google/cadvisor:latest
fi

# Start Admiral dashboard
if [ "${INSTALL_ADMIRAL}" -eq "1" ]; then
docker run -d -p ${ADMIRALPORT}:8282 \
       --name admiral vmware/admiral \
       --log-driver=json-file --log-opt max-size=500M --log-opt max-file=10
fi

# Install php packages
cd /var/www/distros/html && \
COMPOSER=composer.json composer install --quiet --no-dev --no-interaction --no-progress

# Create virtualhost sudbomain
mkdir -p /var/www/${SUBDOMAIN}
yes | cp -f /var/www/distros/scripts/000-default.conf /etc/apache2/sites-available/000-default.conf
yes | cp -f /var/www/distros/scripts/"${SUBDOMAIN}".conf /etc/apache2/sites-available/"${SUBDOMAIN}".conf
service apache2 reload

# Install DogitalOcean monitoring
curl -sSL https://agent.digitalocean.com/install.sh | sh

# Pull all docker images
bash /var/www/distros/scripts/pull-images.sh

# Link extra aliases
touch ~/.bashrc
echo -e "if [ -f /var/www/distros/scripts/.docker-aliases ]; then . /var/www/distros/scripts/.docker-aliases fi" >> ~/.bashrc
source ~/.bashrc

# Remove unused packages
apt-get autoremove
