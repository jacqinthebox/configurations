#! /bin/sh

if [ ! -f /tmp/installed ]; then

echo "\nTurning off swap\n"
swapoff -a
cp /etc/fstab ~/fstab.old
sed -i '2 d' /etc/fstab

echo "\nInstalling Docker!\n"
apt-get update && apt-get install -y apt-transport-https ca-certificates software-properties-common docker.io
systemctl start docker &&  systemctl enable docker
usermod -aG docker $USER

echo "\nInstalling Kubernetes\n"
apt-get update && apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet kubeadm kubectl

echo "\nDeploying kubernetes with the Flannel network overlay\n"
kubeadm init --pod-network-cidr=10.244.0.0/16
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/bc79dd1505b0c8681ece4de4c0d86c5cd2643275/Documentation/kube-flannel.yml
touch /tmp/install
else
        echo "It looks like you installed Kubernetes already"
fi

echo "\nArranging access to the cluster for $(logname)\n"
mkdir -p /home/$(logname)/.kube
sudo cp /etc/kubernetes/admin.conf /home/$(logname)/.kube/config
sudo chown $(logname):$(logname) /home/$(logname)/.kube/config

echo "\nTaint the master so it can host pods\n"
kubectl taint nodes --all node-role.kubernetes.io/master-

echo "\nInstall Dashboard\n"
kubectl create serviceaccount cluster-admin-dashboard-sa
kubectl create clusterrolebinding cluster-admin-dashboard-sa --clusterrole=cluster-admin --serviceaccount=default:cluster-admin-dashboard-sa
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml

echo "\nInstall Helm, sleep 20 seconds for the Tiller pod to get ready and then install Ingress\n"
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get | bash
kubectl create clusterrolebinding permissive-binding --clusterrole=cluster-admin --user=admin --user=kubelet --group=system:serviceaccounts
helm init --service-account default
sleep 20s
helm install stable/nginx-ingress --namespace kube-system --set controller.hostNetwork=true --set rbac.create=true --set controller.kind=DaemonSet

echo "\nCreate some log folders\n"
mkdir -p /var/peterconnects/db

echo "\nAll done!\n"
