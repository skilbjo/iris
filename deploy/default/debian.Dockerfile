FROM quay.io/skilbjo/engineering:debian-latest

COPY deploy                      /usr/local/deploy
COPY resources                   /usr/local/resources
COPY src                         /usr/local/src
COPY dev-resources/test-file.csv  /tmp/portfolio.csv
COPY dev-resources/test-file.html /tmp/portfolio.html

RUN apt-get update && apt-get install gpgsm \
    && apt-mark auto gpgsm
