# Path to your oh-my-zsh installation.
export ZSH="${HOME}/.oh-my-zsh"
ZSH_THEME="powerlevel10k"
plugins=(git last-working-dir zsh-completions kubetail)
source $ZSH/oh-my-zsh.sh
export LANG=en_US.UTF-8

if [ /usr/bin/kubectl ]; then source <(kubectl completion zsh); fi
alias h="history | grep"
alias commitmsg="cp ~/commit-msg .git/hooks && chmod u=rwx .git/hooks/commit-msg"
alias vi=vim
alias v=vim
export KUBE_EDITOR="vim"
alias k=kubectl
alias kx=kubectx
alias kn=kubens
alias ke="kubectl get events --sort-by=.metadata.creationTimestamp"
alias nodes="kubectl get pod -o=custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName --sort-by=.spec.nodeName"
export PATH=$PATH:/usr/local/go/bin
#history no lines
alias hnl="history | cut -c 6-"

get_secret() {
  kubectl get secret ${1} -o json | jq -r .data.secret | base64 -d
}

set_secret() {
  kubectl create secret generic ${1} --from-literal=secret="${2}" --dry-run=client -o json | kubectl apply -f  -
}

kube_backup() {
  for n in $(kubectl get -o=name configmap,ingress,service,deployment,statefulset,pvc,secret)
  do
          echo "backing up $n"
          mkdir -p $(dirname $n)
          kubectl get -o yaml $n > $n.yaml
  done
}

clone(){
 git clone https://gerrit.dev.peterconnects.com/a/"${2}"
}

pushit() {
   git add . && git commit -am "${1}" && git push origin "${2}"
}

source /etc/bash_completion.d/azure-cli
set rtp+=~/.fzf

source $HOME}/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
