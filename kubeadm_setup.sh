#!/bin/bash

# INSTALLING KUBERNETES VERSION 1.26

apt-get update && apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet=1.26.0-00 kubeadm=1.26.0-00  kubectl=1.26.0-00 
apt-mark hold kubelet kubeadm kubectl

#INSTALLING AND CONFIGURING DOCKER

apt-get remove docker docker-engine docker.io containerd runc
#apt-get update
#apt-get install -y   ca-certificates     curl     gnupg     lsb-release
#mkdir -p /etc/apt/keyrings
#curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
#echo \
 # "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
 # $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
#apt-get update
#apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
#mkdir -p /etc/systemd/system/docker.service.d
#systemctl daemon-reload
#systemctl restart docker
#systemctl enable docker
#rm /etc/containerd/config.toml
#systemctl restart containerd

apt install docker.io -y
systemctl start docker
systemctl enable docker

wget https://github.com/Mirantis/cri-dockerd/releases/download/v0.2.5/cri-dockerd-0.2.5.amd64.tgz
tar -xvf cri-dockerd-0.2.5.amd64.tgz
cd cri-dockerd/
mkdir -p /usr/local/bin
install -o root -g root -m 0755 ./cri-dockerd /usr/local/bin/cri-dockerd

sudo tee /etc/systemd/system/cri-docker.service << EOF
[Unit]
Description=CRI Interface for Docker Application Container Engine
Documentation=https://docs.mirantis.com
After=network-online.target firewalld.service docker.service
Wants=network-online.target
Requires=cri-docker.socket
[Service]
Type=notify
ExecStart=/usr/local/bin/cri-dockerd --container-runtime-endpoint fd:// --network-plugin=
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutSec=0
RestartSec=2
Restart=always
StartLimitBurst=3
StartLimitInterval=60s
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
Delegate=yes
KillMode=process
[Install]
WantedBy=multi-user.target
EOF

#sudo tee /etc/systemd/system/cri-docker.socket << EOF
#[Unit]
#Description=CRI Docker Socket for the API
#PartOf=cri-docker.service
#[Socket]
#ListenStream=%t/cri-dockerd.sock
#SocketMode=0660
#SocketUser=root
#SocketGroup=docker
#[Install]
#WantedBy=sockets.target
#EOF

#Daemon reload
systemctl daemon-reload
systemctl enable cri-docker.service
systemctl enable --now cri-docker.socket

# Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system


# INITIALIZING KUBERNETES

#kubeadm init --config /etc/kubernetes/aws.yaml

kubeadm init --apiserver-advertise-address $(hostname -i) --pod-network-cidr=192.168.0.0/16

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
#export kubever=$(kubectl version | base64 | tr -d '\n')


# INSTALLING CALICO 

kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml

