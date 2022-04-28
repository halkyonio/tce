## TIPS

### Convert the docker inspect into a docker run command

See docker templates 
- https://gist.github.com/ictus4u/e28b47dc826644412629093d5c9185be
- https://gist.github.com/efrecon/8ce9c75d518b6eb863f667442d7bc679

```bash
CONTAINER_ID=7dc403a17d87
docker container inspect $CONTAINER_ID

TEMPLATE=https://gist.githubusercontent.com/ictus4u/e28b47dc826644412629093d5c9185be/raw/0fa588100340d31d223c70c168e0665a2aa56839/run.tpl
docker inspect --format "$(curl -s $TPL)" $CONTAINER_ID
docker run \
  --name "/tkg-mgmt-docker-20220428104840-lb"\
  --privileged\
  --runtime "runc"\
  --volume "/lib/modules:/lib/modules:ro"\
  --log-driver "json-file"\
  --restart "unless-stopped"\
  --network "kind"\
  --network-alias "7dc403a17d87"\
  --network-alias "tkg-mgmt-docker-20220428104840-lb"\
  --hostname "tkg-mgmt-docker-20220428104840-lb"\
  --expose "41659/tcp"\
  --expose "6443/tcp"\
  --env "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"\
  --env "SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"\
  --label "io.x-k8s.kind.cluster"="tkg-mgmt-docker-20220428104840"\
  --label "io.x-k8s.kind.role"="external-load-balancer"\
  --detach\
  --tty\
  "kindest/haproxy:v20210715-a6da3463
```
