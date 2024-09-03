FROM ubuntu:latest

RUN apt update -y

RUN apt-get install -y bzip2

RUN apt install -y software-properties-common 

RUN add-apt-repository ppa:ondrej/php -y

RUN apt update -y

RUN apt install -y php8.2-cli

COPY . /usr/src/myapp

WORKDIR /usr/src/myapp

RUN chmod +x appdynamics-php-agent/runme.sh

RUN bash appdynamics-php-agent/runme.sh

EXPOSE 8080

CMD [ "php", "-S", "0.0.0.0:8080" ]
