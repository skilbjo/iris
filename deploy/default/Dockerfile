FROM gliderlabs/alpine:3.5

ENV CMD="usr/local/deploy/bin/run-job"




COPY deploy                      /usr/local/deploy
COPY resources                   /usr/local/resources
COPY src                         /usr/local/src
COPY deploy/default/bashrc       /root/.bashrc
COPY deploy/default/vimrc        /root/.vimrc

RUN apk add -U bash bash-completion ca-certificates musl-dev coreutils postgresql-client postfix mutt vim tzdata \
    && cp /usr/share/zoneinfo/America/Los_Angeles /etc/localtime \
    && echo "America/Los_Angeles" >/etc/timezone \
    && rm -rf /var/cache/apk/*
