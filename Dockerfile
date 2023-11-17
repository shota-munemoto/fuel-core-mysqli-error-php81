FROM php:8.1.25-apache-bullseye
LABEL Name=fuel Version=0.0.1
RUN apt update -y
RUN apt install -y unzip less
RUN docker-php-ext-install mysqli
RUN curl https://get.fuelphp.com/oil | sh
# CMD ["sh", "-c", "/usr/games/fortune -a | cowsay"]
