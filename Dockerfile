FROM php:8.3.6-cli

COPY . /usr/src/myapp

WORKDIR /usr/src/myapp

CMD [ "php", "-S", "localhost:8080" ]
