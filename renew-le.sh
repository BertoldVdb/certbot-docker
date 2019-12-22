#!/bin/sh

mkdir -p $KEYDIR/letsencrypt
ln -sf $KEYDIR/letsencrypt /etc/letsencrypt

if [ ! -f $KEYDIR/cert.pem ]; then
	#Make a self signed cert first as it may be required for other parts of the chain to start
	openssl req -new -x509 -days 365 -nodes -out /tmp/cert.pem \
						-keyout /tmp/key.pem \
  						-subj "/CN=tempcert"

	cat /tmp/cert.pem /tmp/key.pem > $KEYDIR/cert.pem
	rm /tmp/cert.pem /tmp/key.pem

	echo "Created self signed cert. Waiting 30s"
	sleep 30
fi

echo "#!/bin/bash" > /reload.sh
echo "if [ -f /etc/letsencrypt/live/*/fullchain.pem ]; then" >> /reload.sh
echo "  cat /etc/letsencrypt/live/*/fullchain.pem /etc/letsencrypt/live/*/privkey.pem > $KEYDIR/cert.pem" >> /reload.sh
echo "fi" >> /reload.sh
echo "docker kill -s USR2 $RELOAD" >> /reload.sh
chmod +x /reload.sh

while true
do
	if [ "x$DNSNAME" != "x" ]; then
		if [ -f /etc/letsencrypt/live/*/fullchain.pem ]; then
	    		certbot renew --http-01-port=4433 --preferred-challenges http --deploy-hook /reload.sh
		else
			certbot certonly --force-renewal --expand --standalone $DNSNAME --non-interactive --agree-tos --email ${EMAIL:=vandenbergh@bertold.org} --must-staple --http-01-port=4433 --preferred-challenges http
			/reload.sh
		fi
	fi

	for i in `seq 0 23`
	do
		if [ -f $KEYDIR/cert.pem ]; then
			if [ -S $HAPROXY_SOCKET ]; then
				/haproxy-ocsp-stapling-updater/hapos-upd --cert $KEYDIR/cert.pem --socket $HAPROXY_SOCKET
				if [ $? -eq 5 ]; then
					echo "Failed to update stapling, performing reload"
					/reload.sh
				fi
			fi
		fi
		sleep 7200
	done
done
