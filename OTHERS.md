## Kubernetes dashboard

### Deploy it using the package repository

**Note**: The Kubernetes dashboard can be installed now using the following commands

```bash
tanzu package repository add demo-repo --url ghcr.io/halkyonio/packages/demo-repo:0.1.0 -n kube --create-namespace

cat <<EOF > $TEMP_DIR/values-k8s-ui.yml
vm_ip: $VM_IP
EOF
tanzu package install k8s-ui -p kubernetes-dashboard.halkyonio.io -v -n kube -f $TEMP_DIR/values-k8s-ui.yml
```
Next, access the Dashboard using the URL `https://k8s-ui.$VM_IP.nip.io"` and token
```bash
kubectl rollout status deployment/kubernetes-dashboard -n kubernetes-dashboard --timeout=240s
kubectl get secret $(kubectl get serviceaccount kubernetes-dashboard -n kubernetes-dashboard -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data.token}" -n kubernetes-dashboard | base64 --decode)
```

### Old instructions (deprecated)

Setup the Issuer & Certificate resources used by the certificate Manager to generate a selfsigned certificate and dnsNames `k8s-ui.$IP.nip.io` using Letscencrypt.
The secret name `k8s-ui-secret` referenced by the Certificate resource will be filled by the Certificate Manager and next used by the Ingress TLS endpoint
```bash
IP=65.108.148.216
kc delete issuer.cert-manager.io/letsencrypt-staging -n kubernetes-dashboard
kc delete certificate.cert-manager.io/letsencrypt-staging -n kubernetes-dashboard

cat <<EOF | kubectl apply -f -
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt-staging
  namespace: kubernetes-dashboard
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: cmoulliard@redhat.com
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
      - http01:
          ingress:
            name: k8s-ui-kubernetes-dashboard
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: letsencrypt-staging
  namespace: kubernetes-dashboard
spec:
  secretName: k8s-ui-secret
  issuerRef:
    name: letsencrypt-staging
  dnsNames:
  - k8s-ui.$IP.nip.io
EOF
```

Configure and deploy and the helm chart
```bash
IP=65.108.148.216
cat <<EOF > $HOME/k8s-ui-values.yml
ingress:
  enabled: true
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-staging
    projectcontour.io/ingress.class: contour
  hosts:
  - k8s-ui.$IP.nip.io
  tls:
  - secretName: k8s-ui-secret
    hosts:
      - k8s-ui.$IP.nip.io
service:
  annotations:
    projectcontour.io/upstream-protocol.tls: "443"      
EOF
helm uninstall k8s-ui -n kubernetes-dashboard
helm install k8s-ui kubernetes-dashboard/kubernetes-dashboard -n kubernetes-dashboard -f k8s-ui-values.yml
```

Grant the `cluster-admin` role to the k8s dashboard service account and next get the token to be logged using the UI
```bash
kubectl create serviceaccount dashboard -n kubernetes-dashboard
kubectl create clusterrolebinding dashboard-admin -n kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kubernetes-dashboard:dashboard
kubectl get secret $(kubectl get sa/dashboard -n kubernetes-dashboard -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data.token}" -n kubernetes-dashboard | base64 --decode
```
Open the browser at this address: `https://k8s-ui.$IP.nip.io`

## Install, upgrade needed tools

Install or upgrade tools on Centos7
```bash
sudo yum install bash-completion
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install docker-ce docker-ce-cli containerd.io
sudo systemctl start docker
sudo systemctl enable docker
sudo groupadd docker
sudo usermod -aG docker $USER
sudo reboot
```
Enable a new port that we will use as NodePort
```bash
sudo firewall-cmd --permanent --add-port=32510/tcp
sudo firewall-cmd --reload
```

Upgrade curl and git as needed by homebrew
```bash
sudo bash -c 'cat << EOF > /etc/yum.repos.d/city-fan.repo
[CityFan]
name=City Fan Repo
baseurl=http://www.city-fan.org/ftp/contrib/yum-repo/rhel7/x86_64/
enabled=1
gpgcheck=0
EOF'
sudo yum install curl -y

sudo yum -y remove git-*
sudo yum -y install https://packages.endpointdev.com/rhel/7/os/x86_64/endpoint-repo.x86_64.rpm
sudo yum install git -y 
```

Install homebrew
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/snowdrop/.bash_profile
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
```
Install some additional k8s and Carvel tools
```bash
VERSION=v1.21.0
curl -LO https://dl.k8s.io/release/$VERSION/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin
chmod 600 $HOME/.kube/config

(set -x; cd "$(mktemp -d)" &&   OS="$(uname | tr '[:upper:]' '[:lower:]')" &&   ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&   KREW="krew-${OS}_${ARCH}" &&   curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&   tar zxvf "${KREW}.tar.gz" &&   ./"${KREW}" install krew;)

printf "\n# Kubectl krew\nexport PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"\n" >> $HOME/.bashrc

kubectl krew install tree
printf "\nalias ktree="kubectl tree"\n" >> $HOME/.bashrc
printf "\nalias tz="tanzu"\n" >> $HOME/.bashrc
printf "\nalias kc="kubectl"\n" >> $HOME/.bashrc

brew tap vmware-tanzu/carvel
brew install kapp
brew install ytt
brew install imgpkg
brew install crane
```
