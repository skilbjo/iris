# iris

[CircleCI Builds](https://circleci.com/gh/skilbjo/iris)

[![CircleCI](https://circleci.com/gh/skilbjo/iris/tree/master.svg?style=svg&circle-token=b5df007c0340b050afa100df2ec921f264362ddd)](https://circleci.com/gh/skilbjo/iris/tree/master)
[![Docker Repository on Quay](https://quay.io/repository/skilbjo/iris/status "Docker Repository on Quay")](https://quay.io/repository/skilbjo/iris)

<img src='dev-resources/img/iris.jpg' width='500' />

## what

Email reporting of financial data

## environment variables
```bash
export email=''
export email_pw=''

# bare metal
export db_uri='postgres://postgres@192.168.99.100:5432/postgres'

# aws lambda
export aws_access_key_id=''
export aws_secret_access_key=''
```

## minicontainer // minidocker

```bash
minidock \
  -i iris:dev -t iris:minicon --mode loose --apt \
  -E bash -E aws -E jq -E cat -E mkdir -E date -E touch -E sed -E tr -E base64 -E sleep \
  -E ls -E which -E env \
  --include '/usr/local/resources/*' \
  -E '/usr/local/deploy/bin/run-job' -E '/usr/local/src/iris' -E '/usr/local/src/athena' -E '/usr/local/src/util' \
  -- /usr/local/deploy/bin/run-job && ./run-container
```

## links
- <https://gist.github.com/hahnicity/45323026693cdde6a116>
- <https://github.com/grycap/minicon/>

