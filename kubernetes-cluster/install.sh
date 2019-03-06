#! /bin/sh

if [ ! -f /tmp/installed ]; then

echo "\nturning off swap\n"
swapoff -a
cp /etc/fstab ~/fstab.old
sed -i '2 d' /etc/fstab

echo "\ninstalling docker\n"
apt-get update && apt-get install -y apt-transport-https ca-certificates software-properties-common docker.io
systemctl start docker &&  systemctl enable docker
usermod -aG docker $USER

echo "\ninstalling kubernetes\n"
apt-get update && apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet kubeadm kubectl

echo "\ndeploying kubernetes with flannel\n"
kubeadm init --pod-network-cidr=10.244.0.0/16
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/bc79dd1505b0c8681ece4de4c0d86c5cd2643275/Documentation/kube-flannel.yml
touch /tmp/install
else
        echo "It looks like you installed Kubernetes already"
fi

echo "\narranging access to the cluster for $(logname)\n"
mkdir -p /home/$(logname)/.kube
sudo cp /etc/kubernetes/admin.conf /home/$(logname)/.kube/config
sudo chown $(logname):$(logname) /home/$(logname)/.kube/config

echo "\nTaint the master so it can host pods\n"
kubectl taint nodes --all node-role.kubernetes.io/master-

echo "\nInstall Dashboard and Helm. Then sleep 20 seconds for the Tiller pod to get ready\n"
kubectl create serviceaccount cluster-admin-dashboard-sa
kubectl create clusterrolebinding cluster-admin-dashboard-sa --clusterrole=cluster-admin --serviceaccount=default:cluster-admin-dashboard-sa
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get | bash
kubectl create clusterrolebinding permissive-binding --clusterrole=cluster-admin --user=admin --user=kubelet --group=system:serviceaccounts
helm init --service-account default
sleep 20s
helm install stable/nginx-ingress --namespace kube-system --set controller.hostNetwork=true --set rbac.create=true --set controller.kind=DaemonSet

echo "\nCreate some log folders\n"
mkdir -p /var/peterconnects/db

echo "\nDone\n"
