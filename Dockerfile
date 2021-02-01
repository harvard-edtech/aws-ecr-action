FROM docker:19.03.14

RUN apk update && apk upgrade
RUN apk add --no-cache \
  python3 py3-pip coreutils bash git nodejs curl \
  && pip3 install -U pip \
  && pip3 install awscli \
  && rm -rf /var/cache/apk/*

RUN curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | \
  sh -s -- -b /usr/local/bin

ADD entrypoint.sh /entrypoint.sh

RUN ["chmod", "+x", "/entrypoint.sh"]

ENTRYPOINT ["/entrypoint.sh"]
