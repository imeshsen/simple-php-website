FROM ubuntu:latest

RUN apt update -y

RUN apt install -y php8.3-cli 

COPY . /usr/src/myapp

WORKDIR /usr/src/myapp

#RUN chmod +x appdynamics-php-agent/runme.sh

#RUN bash appdynamics-php-agent/runme.sh

EXPOSE 8080

CMD [ "php", "-S", "0.0.0.0:8080" ]
