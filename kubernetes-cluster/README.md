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

* execute `ssh-keygen` on the console node

On every node:  

* become root 
* paste your public key to authorized_keys
* in sshd_config uncomment PermitRootLogin
* in sshd_config uncomment authorized_keys file
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


### Dashoard

Download kubectl on your desktop and copy the K8s config file to the .kube folder.

This guy is the best:  
[https://iamchuka.com/install-kubernetes-dashboard-part-iii/](https://iamchuka.com/install-kubernetes-dashboard-part-iii/)

```sh
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recomm
ended/kubernetes-dashboard.yaml

kubectl proxy

http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/#!/login

```

We need to create the admin user: 

```
kubectl apply -f https://gist.githubusercontent.com/chukaofili/9e94d966e73566eba5abdca7ccb067e6/raw/0f17cd37d2932fb4c3a2e7f4434d08bc64432090/k8s-dashboard-admin-user.yaml
```

Get the token. This is a bit verbose  

```sh
 kubectl get sa
 kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')
 kubectl get sa admin-user -n kube-system
 kubectl describe sa admin-user -n kube-system
 kubectl describe secret admin-user-token-5mrvc -n kube-system
```

Paste the token in the login form.

