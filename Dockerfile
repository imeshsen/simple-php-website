FROM ubuntu:24.04

COPY . /usr/src/myapp

WORKDIR /usr/src/myapp

RUN ./execute.sh

RUN chmod +x appdynamics-php-agent-linux_x64/runme.sh

#RUN bash appdynamics-php-agent-linux_x64/runme.sh

#RUN nohup php -S 0.0.0.0:8080

EXPOSE 8080

#CMD bash appdynamics-php-agent-linux_x64/runme.sh

CMD [ "php", "-S", "0.0.0.0:8080" ]
