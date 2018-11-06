FROM gliderlabs/alpine:3.5

ENV CMD="/usr/local/deploy/bin/run-job"




COPY deploy                      /usr/local/deploy
COPY resources                   /usr/local/resources
COPY src                         /usr/local/src
COPY deploy/default/bashrc       /root/.bashrc
COPY deploy/default/vimrc        /root/.vimrc

RUN apk add --no-cache bash bash-completion ca-certificates curl coreutils postgresql-client postfix mutt git vim unzip tzdata jq py-pip python-dev \
    && pip install --upgrade awscli && mkdir /root/.aws && chmod 700 /root/.aws \
    && mkdir -p /root/.vim  && git clone https://github.com/Shougo/neobundle.vim ~/.vim/bundle && ~/.vim/bundle/bin/install.sh \
    && cp /usr/share/zoneinfo/America/Los_Angeles /etc/localtime \
    && echo "America/Los_Angeles" >/etc/timezone
