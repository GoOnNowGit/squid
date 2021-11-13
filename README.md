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

### Create the secret using existing key-pair or self-signed above
```
kubectl create secret tls squid.tls --cert=tls.crt --key=tls.key
```

### Apply the deployment
```
kubectl apply -f squid.yml
```

### Delete the deployment
```
kubectl delete -f squid.yml
```

## References
* https://wiki.squid-cache.org/SquidFaq/CompilingSquid
* https://wiki.squid-cache.org/ConfigExamples/ContentAdaptation/eCAP
* https://github.com/sameersbn/docker-squid.git
