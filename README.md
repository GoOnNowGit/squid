# squid-container-fun
Squid from source

## Build image
```
docker-compose build
```

## kubernetes Setup

### Make a self-signed cert (Testing purposes)
```
openssl req -newkey rsa:2048 -x509 -sha256 -days 365 -nodes -out tls.crt -keyout tls.key
```

### Create dhparam file
```
openssl dhparam -out confs/dhparams.pem 2048
```

### Create confs config map
```
kubectl create configmap squid.config --from-file=confs
```
### Create acls config map

```
kubectl create configmap squid.acls --from-file=acls 
```

### Create secret using existing key-pair or self-signed above
```
kubectl create secret tls squid.tls --cert=tls.crt --key=tls.key
```

### Apply the deployment
```
kubectl apply -f kubernetes/squid.yml
```

### Delete the deployment
```
kubectl delete -f kubernetes/squid.yml
```

### Connect via the proxy
```
curl --proxy http://127.0.0.1:3128 --proxy-cacert tls.crt www.google.com
```

## References
* https://wiki.squid-cache.org/SquidFaq/CompilingSquid
* https://wiki.squid-cache.org/ConfigExamples/ContentAdaptation/eCAP
* https://github.com/sameersbn/docker-squid.git
* https://github.com/yvoinov/squid-ecap-exif
* https://github.com/yvoinov/squid-ecap-gzip
