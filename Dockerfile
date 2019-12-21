FROM alpine:edge

RUN apk update \
 && apk upgrade \
 && apk add --no-cache \
        ca-certificates \
	git certbot \
	socat openssl bash coreutils \
	docker-cli gawk \
 && update-ca-certificates \
 && git clone https://github.com/pierky/haproxy-ocsp-stapling-updater.git \
 && wget -O /usr/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_amd64 \
 && chmod +x /usr/bin/dumb-init

COPY renew-le.sh /

ENTRYPOINT ["/usr/bin/dumb-init"]
CMD ["/renew-le.sh"] 
