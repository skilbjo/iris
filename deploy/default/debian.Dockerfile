FROM quay.io/skilbjo/engineering:debian-latest

COPY deploy                      /usr/local/deploy
COPY resources                   /usr/local/resources
COPY src                         /usr/local/src
