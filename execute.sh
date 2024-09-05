#!/bin/bash
#

apt update -y

apt-get install -y bzip2

apt install -y software-properties-common

add-apt-repository ppa:ondrej/php -y

apt update -y

apt install -y php8.2-cli
