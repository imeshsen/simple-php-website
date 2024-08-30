FROM php:8.3.6-cli

COPY . /usr/src/myapp

WORKDIR /usr/src/myapp

RUN chmod +x appdynamics-php-agent/runme.sh

RUN bash appdynamics-php-agent/runme.sh

EXPOSE 8080

CMD [ "php", "-S", "0.0.0.0:8080" ]
