#!/usr/bin/env bash

INSTALL_TYPE=$1
# If INSTALL_TYPE is null or not set, set INSTALL_TYPE to all
: "${INSTALL_TYPE:=all}"

# Common utilities, variables and checks for all scripts.
# Instructs a shell to exit if a command fails, i.e., if it outputs a non-zero exit status.
# equivalent to set -e
set -o errexit

# Treats unset or undefined variables as an error when substituting (during parameter expansion).
# Does not apply to special parameters such as wildcard * or @.
# equivalent to set -u
set -o nounset

# The return value of a pipeline is the status of the last command that had a non-zero status upon exit.
# If no command had a non-zero status upon exit, the value is zero.
set -o pipefail

# Gather variables about bootstrap system
USR_BIN_PATH=/usr/local/bin
export PATH="${PATH}:${USR_BIN_PATH}"
ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')

# Define glob variables
KUBE_ROOT="$(cd "$(dirname "$0")" && pwd)"
CERTS_DIR="${KUBE_ROOT}/config/certs"
CONFIG_FILE="${KUBE_ROOT}/config.yaml"
CA_CONFIGFILE="${KUBE_ROOT}/config/rootCA.cnf"
COMPOSE_YAML_FILE="${KUBE_ROOT}/compose.yaml"
IMAGES_DIR="${KUBE_ROOT}/resources/images"
COMPOSE_CONFIG_DIR="${KUBE_ROOT}/config/compose"
OUTPUT_ENV_FILE="${KUBE_ROOT}/.install-env.sh"
RESOURCES_NGINX_DIR="${KUBE_ROOT}/resources/nginx"
KUBESPRAY_CONFIG_DIR="${KUBE_ROOT}/config/kubespray"
INSTALL_STEPS_FILE="${KUBESPRAY_CONFIG_DIR}/.install_steps"

# Include all functions from library/*.sh
for file in "${KUBE_ROOT}"/library/*.sh; do source "${file}"; done

# Gather os-release variables
if ! source /etc/os-release; then
  errorlog "Every system that we officially support has /etc/os-release"
  exit 1
fi

if [ ! -f "${CONFIG_FILE}" ]; then
  errorlog "The ${CONFIG_FILE} file is not existing"
  exit 1
fi

deploy_compose(){
  if grep -q 'deploy_compose' "${KUBE_ROOT}"/.install_steps; then
    common::rudder_config
    common::load_images
    common::health_check
    return 0
  fi
  # ID is from the step below: source /etc/os-release
  case ${ID} in
    Debian|debian)
      system::debian::config_repo
      ;;
    CentOS|centos)
      system::centos::disable_selinux
      system::centos::config_repo
      ;;
    Fedora|fedora)
      system::fedora::disable_selinux
      system::fedora::config_repo
      ;;
    Ubuntu|ubuntu)
      system::ubuntu::config_repo
      ;;
    *)
      errorlog "Not support system: ${ID}"
      exit 1
      ;;
  esac
  system::disable_firewalld
  system::install_pkgs
  common::install_tools
  common::rudder_config
  common::update_hosts
  system::install_chrony
  common::generate_domain_certs
  common::load_images
  common::compose_up
  common::health_check
  echo 'deploy_compose' > "${KUBE_ROOT}"/.install_steps
}

main(){
  case ${INSTALL_TYPE} in
    all)
      deploy_compose
      common::push_kubespray_image
      common::run_kubespray "bash /kubespray/run.sh deploy-cluster"
      ;;
    compose)
      deploy_compose
      ;;
    cluster)
      common::rudder_config
      common::push_kubespray_image
      common::run_kubespray "bash /kubespray/run.sh deploy-cluster"
      ;;
    remove)
      common::rudder_config
      remove::remove_cluster
      remove::remove_compose
      ;;
    remove-cluster)
      common::rudder_config
      remove::remove_cluster
      ;;
    remove-compose)
      common::rudder_config
      remove::remove_compose
      ;;
    add-node)
      common::run_kubespray "bash /kubespray/run.sh add-node $2"
      ;;
    remove-node)
      common::run_kubespray "bash /kubespray/run.sh remove-node $2"
      ;;
    health-check)
      common::health_check
      ;;
    debug)
      common::run_kubespray "bash"
      ;;
    -h|--help|help)
      common::usage
      ;;
    *)
      echowarn "unknow [TYPE] parameter: ${INSTALL_TYPE}"
      common::usage
      ;;
  esac
}

main "$@"
