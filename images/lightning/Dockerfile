FROM drupal8/distros

MAINTAINER Theodoros Ploumis - www.theodorosploumis.com

ENV NEWDISTRO="lightning" \
    PROFILE="lightning" \
    DOCROOT="/var/www/html/docroot" \
    PACKAGE="acquia/lightning-project"

RUN COMPOSER=composer.json composer create-project ${PACKAGE} /var/www/${NEWDISTRO} \
    --quiet --no-ansi --no-dev --no-interaction --no-progress

RUN composer clear-cache

RUN rm -rf /var/www/html && \
    mv /var/www/${NEWDISTRO} /var/www/html

RUN sed -i 's/\/var\/www\/html/'"\/var\/www\/html\/docroot"'/g' /etc/apache2/sites-available/000-default.conf

# Prepare installation
RUN bash /var/www/prepare-install.sh

RUN sed -i 's/2000000/'"0"'/g' /var/www/html/docroot/sites/default/default.services.yml

# Install Drupal
WORKDIR ${DOCROOT}
RUN bash /var/www/install.sh
