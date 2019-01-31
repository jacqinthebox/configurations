# Install Kubernetes (work in progress)

This is how to install a Kubernetes cluster on bare metal. You can use the Vagrantfile or the Azure Resource Manager templates to install 3 Ubuntu 18.04 servers.

Thanks to [https://www.digitalocean.com/community/tutorials/how-to-create-a-kubernetes-1-11-cluster-using-kubeadm-on-ubuntu-18-04](https://www.digitalocean.com/community/tutorials/how-to-create-a-kubernetes-1-11-cluster-using-kubeadm-on-ubuntu-18-04)

## Deploy the ARM template

Install the Azure CLI:  

```sh
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | \
    sudo tee /etc/apt/sources.list.d/azure-cli.list
az login
az account set --subscription "c8de5b2dxxxxxxx"

```

You are of course free to rename the resource group. :)  

```sh
az group create --name kube-cluster-jacq --location "West Europe"
az group deployment create -g kube-cluster-jacq  -n initial-deployment --template-file azuredeploy.json --parameters @parameters.json
az group delete --name kube-cluster-jacq
```


## Make sure you can login as root on all the nodes

* execute `ssh-keygen` on your console

On every node:  

* become root 
* paste the pub key of your console to authorized_keys of the node
* in sshd_config set PermitRootLogin prohibit-password
* set PubkeyAuthentication yes
* uncomment authorized_keys file
* `service sshd restart`


## Install Ansible on the console machine

```sh
sudo apt update && sudo apt-get upgrade -y 
sudo apt install software-properties-common -y
sudo apt-add-repository ppa:ansible/ansible
sudo apt update
sudo apt install ansible -y

```

## Create and edit the host file (replace the ip's)

Again on the console machine: 

```sh
wget https://raw.githubusercontent.com/jacqinthebox/arm-templates-and-configs/master/kubernetes-cluster/hosts

```


## Fetch the Ansible playbooks

On the console machine:  

```sh
mkdir ~/kube-cluster
cd kube-cluster
wget https://raw.githubusercontent.com/jacqinthebox/arm-templates-and-configs/master/kubernetes-cluster/workers.yml
wget https://raw.githubusercontent.com/jacqinthebox/arm-templates-and-configs/master/kubernetes-cluster/initial.yml
wget https://raw.githubusercontent.com/jacqinthebox/arm-templates-and-configs/master/kubernetes-cluster/master.yml
wget https://raw.githubusercontent.com/jacqinthebox/arm-templates-and-configs/master/kubernetes-cluster/kube-dependencies.yml
```

## Execute the playbooks

On the console machine:  

```sh
ansible-playbook -i hosts ~/kube-cluster/initial.yml
ansible-playbook -i hosts ~/kube-cluster/kube-dependencies.yml
ansible-playbook -i hosts ~/kube-cluster/master.yml
ansible-playbook -i hosts ~/kube-cluster/workers.yml

```

## Check it out



```
sh root@masternode_ip

kubectl get nodes

```

If they are not ready there might be a problem with flannel.


```
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/v0.10.0/Documentation/kube-flannel.yml

```
or:  

```
kubectl -n kube-system apply -f https://raw.githubusercontent.com/coreos/flannel/bc79dd1505b0c8681ece4de4c0d86c5cd2643275/Documentation/kube-flannel.yml
```

Also look here:  

[http://joecreager.com/troubleshooting-kubernetes-worker-node-notready/](http://joecreager.com/troubleshooting-kubernetes-worker-node-notready/)

# Install a single node

```sh
#!/bin/bash
echo "installing docker"
apt-get update && apt-get upgrade -y
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    docker.io

systemctl start docker &&  systemctl enable docker
usermod -aG docker $USER

echo "installing kubernetes"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update && apt-get install -y kubelet kubeadm kubectl

echo "deploying kubernetes with flannel"
kubeadm init --pod-network-cidr=10.244.0.0/16 #--apiserver-advertise-address=192.168.2.171
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/bc79dd1505b0c8681ece4de4c0d86c5cd2643275/Documentation/kube-flannel.yml
```

Export the config

```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Taint the node
```
kubectl taint nodes --all node-role.kubernetes.io/master-
```

Install the dashboard
#https://docs.giantswarm.io/guides/install-kubernetes-dashboard/
```
kubectl get pods --all-namespaces
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml

kubectl create serviceaccount cluster-admin-dashboard-sa
kubectl create clusterrolebinding cluster-admin-dashboard-sa \
  --clusterrole=cluster-admin \
  --serviceaccount=default:cluster-admin-dashboard-sa

kubectl get secret | grep cluster-admin-dashboard-sa
```

# Install something

```bash
cat > microbot-daemonset.yaml <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: microbot-app-1
  namespace: microbots-dev
  labels:
    app: microbots
spec:
  selector:
    matchLabels:
      name: microbot-app-1
  template:
    metadata:
      labels:
        name: microbot-app-1
    spec:
      containers:
      - name: microbot1
        image: jacqueline/microbot:model-1.2
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: microbot-app-2
  namespace: microbots-dev
  labels:
    app: microbots
spec:
  selector:
    matchLabels:
      name: microbot-app-2
  template:
    metadata:
      labels:
        name: microbot-app-2
    spec:
      containers:
      - name: microbot1
        image: jacqueline/microbot:model-2.2
        ports:
        - containerPort: 80
EOF
```

Now the services


```
cat > microbot-service.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: microbot-service-1
  namespace: microbots-dev
spec:
  ports:
  - port: 80
    protocol: TCP
    name: http
  selector:
    name: microbot-app-1
---
apiVersion: v1
kind: Service
metadata:
  name: microbot-service-2
  namespace: microbots-dev
spec:
  ports:
  - port: 80
    protocol: TCP
    name: http
  selector:
    name: microbot-app-2
EOF
```

Now the Ingress
https://github.com/containous/traefik/pull/3582
Don't forget the base url for this to work.

```yml
cat > microbot-ingress.yaml <<EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: microbots-ingress
  namespace: microbots-dev
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.frontend.rule.type: PathPrefixStrip
    # traefik.ingress.kubernetes.io/rewrite-target: "/"
spec:
  rules:
  - host: dev.microbots.io
    http:
      paths:
      - path: /microbot1
        backend:
          serviceName: microbot-service-1
          servicePort: http
      - path: /microbot2
        backend:
          serviceName: microbot-service-2
          servicePort: http
EOF
```


