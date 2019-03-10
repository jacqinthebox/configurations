#! /bin/sh

if [ ! -f /tmp/installed ]; then

if [ -z "$1" ]
then
	echo "You forgot the clustername. You should run the script with a variable like so: sudo ./install.sh clustername"
	echo "Exiting"
	exit 2
fi

echo "[prepare] Creating the config file for kubeadm"
cat > kubeadm-config.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta1
kind: ClusterConfiguration
clusterName: $1
networking:
  podSubnet: 10.244.0.0/16
EOF

echo "[prepare] Turning off swap"
swapoff -a
cp /etc/fstab ~/fstab.old
sed -i '2 d' /etc/fstab

echo "[prepare] Installing Docker!"
apt-get update && apt-get install -y apt-transport-https ca-certificates software-properties-common docker.io
systemctl start docker &&  systemctl enable docker
usermod -aG docker $USER

echo "[kube-install] Installing Kubernetes"
apt-get update && apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet kubeadm kubectl

echo "[kube-install] Running kubeadm"
wget https://raw.githubusercontent.com/jacqinthebox/arm-templates-and-configs/optimize-kube/kubernetes-cluster/kubeadm-config.yaml 
kubeadm init --config=kubeadm-config.yaml #--pod-network-cidr=10.244.0.0/16 
export KUBECONFIG=/etc/kubernetes/admin.conf

echo "[postdeployment] Installing Flannel"
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/bc79dd1505b0c8681ece4de4c0d86c5cd2643275/Documentation/kube-flannel.yml
touch /tmp/installed
else
        echo "It looks like you installed already installed Kubernetes"
fi

echo "[postdeployment] Arranging access to the cluster for $(logname)\n"
mkdir -p /home/$(logname)/.kube
sudo cp /etc/kubernetes/admin.conf /home/$(logname)/.kube/config
sudo chown $(logname):$(logname) /home/$(logname)/.kube/config

echo "[postdeployment] Taint the master so it can host pods"
kubectl taint nodes --all node-role.kubernetes.io/master-

echo "[postdeployment] Install Dashboard"
kubectl create serviceaccount cluster-admin-dashboard-sa
kubectl create clusterrolebinding cluster-admin-dashboard-sa --clusterrole=cluster-admin --serviceaccount=default:cluster-admin-dashboard-sa
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml

echo "[postdeployment] Install Helm, wait for the Tiller pod to get ready"

curl https://raw.githubusercontent.com/helm/helm/master/scripts/get | bash
kubectl create clusterrolebinding permissive-binding --clusterrole=cluster-admin --user=admin --user=kubelet --group=system:serviceaccounts
helm init --service-account default

ATTEMPTS=0
ROLLOUT_STATUS_CMD="kubectl rollout status deployment/tiller-deploy -n kube-system"
until $ROLLOUT_STATUS_CMD || [ $ATTEMPTS -eq 60 ]; do
  $ROLLOUT_STATUS_CMD
  ATTEMPTS=$((attempts + 1))
  sleep 10
done


echo "[postdeployment] Install Ingress"

helm install stable/nginx-ingress --name v1 --namespace kube-system --set controller.hostNetwork=true --set rbac.create=true --set controller.kind=Deployment --set controller.extraArgs.v=2 --set controller.extraArgs.tcp-services-configmap=default/sql-services

echo "[postdeployment] Exposing port 1433"
kubectl -n kube-system delete deployment v1-nginx-ingress-controller  
kubectl apply -f https://raw.githubusercontent.com/jacqinthebox/arm-templates-and-configs/optimize-kube/kubernetes-cluster/v21-ingress-deployment.yaml
kubectl apply -f https://raw.githubusercontent.com/jacqinthebox/arm-templates-and-configs/optimize-kube/kubernetes-cluster/sql-server-configmap.yaml

echo "[postdeployment] Set the Kubernetes Dashboard to NodePort"
kubectl -n kube-system get service/kubernetes-dashboard -o yaml | sed "s/type: ClusterIP/type: NodePort/" | kubectl replace -f -

echo "[postdeployment] Creating shared folders to mount into the pods"
mkdir -p /var/peterconnects/db

echo "[end] If you want do reinitialize the cluster, run kubeadm reset --force AND delete the /tmp/installed file."
echo "[end] Run kubectl get secret | grep cluster-admin-dashboard-sa and then kubectl describe secret <secretname> to get the token for the dashboard."
echo "[end] Run kubectl -n kube-system get service kubernetes-dashboard to get the port number of the Dashboard."
echo "[end] Thank you and see you later."
