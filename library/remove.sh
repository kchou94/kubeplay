#!/usr/bin/env bash
remove::remove_cluster(){
  common::run_kubespray "bash /kubespray/run.sh remove-cluster"
  rm -f "${INSTALL_STEPS_FILE}"
}

remove::cleanup(){
  # Remove registry domain form /etc/hosts
  sed -i "/${REGISTRY_DOMAIN}/d" /etc/hosts
  mkcert -uninstall
  # Remove binary tools file
  rm -f "${USR_BIN_PATH}"/{kubectl,helm,yq,mkcert,skopeo}
  rm -f "${KUBE_ROOT}"/.install_steps
}

remove::uninstall_nerdctl_full(){
  nerdctl compose -f "${COMPOSE_YAML_FILE}" down
  nerdctl ps -a -q | xargs -L1 -I {} sh -c "nerdctl stop {}; nerdctl rm -f {}" || true
  systemctl disable containerd buildkit --now
  find "${RESOURCES_NGINX_DIR}"/tools -type f -name "nerdctl-full-*-linux-${ARCH}.tar.gz" | sort -r --version-sort | head -n1 \
  | xargs -L1 -I {} tar -tf {} | grep -v '/$' | xargs -I {} rm -rf /usr/local/{}
  systemctl daemon-reload
}

remove::remove_compose(){
  remove::uninstall_nerdctl_full
  remove::cleanup
}
