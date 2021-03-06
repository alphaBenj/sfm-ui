FROM gwul/sfm-base@sha256:bf84472ee4819b86a90a39c184f190b5ab769026eb427fe784625f3148490e55
MAINTAINER Justin Littman <justinlittman@gwu.edu>

# Install apache
RUN apt-get update && apt-get install -y \
    apache2=2.4.10-10+deb8u* \
    libapache2-mod-wsgi=4.3.0-1

ADD . /opt/sfm-ui/
WORKDIR /opt/sfm-ui
RUN pip install -r requirements/common.txt -r requirements/release.txt

#This is used to automatically create the admin user.
RUN pip install django-finalware==0.1.0

# Adds fixtures.
ADD docker/ui/fixtures.json /opt/sfm-setup/

# Add envvars. User and group for Apache is set in envvars.
ADD docker/ui/envvars /etc/apache2/

# Enable sfm site
ADD docker/ui/apache.conf /etc/apache2/sites-available/sfm.conf
RUN a2ensite sfm.conf

# Disable pre-existing default site
RUN a2dissite 000-default

ADD docker/ui/invoke.sh /opt/sfm-setup/
RUN chmod +x /opt/sfm-setup/invoke.sh

ADD docker/ui/setup_ui.sh /opt/sfm-setup/
RUN chmod +x /opt/sfm-setup/setup_ui.sh

# Forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/apache2/access.log
RUN ln -sf /dev/stderr /var/log/apache2/error.log

ENV DJANGO_SETTINGS_MODULE=sfm.settings.docker_settings
ENV LOAD_FIXTURES=false
EXPOSE 80

CMD sh /opt/sfm-setup/setup_reqs.sh \
    && appdeps.py --wait-secs 60 --port-wait db:5432 --file /opt/sfm-ui --port-wait mq:5672  --file-wait /sfm-data/collection_set \
    && sh /opt/sfm-setup/setup_ui.sh \
    && sh /opt/sfm-setup/invoke.sh
