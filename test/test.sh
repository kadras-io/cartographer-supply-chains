#!/bin/bash

set -o errexit
set -o pipefail

echo -e "\nš¢ Setting up Kubernetes cluster...\n"

kapp deploy -a test-setup -f test/test-setup -y
kubectl config set-context --current --namespace=carvel-test

# Wait for the generation of a token for the new Service Account
while [ $(kubectl get configmap kube-root-ca.crt --no-headers | wc -l) -eq 0 ] ; do
  sleep 3
done

echo -e "\nš Installing test dependencies..."

kapp deploy -a kapp-controller -y \
  -f https://github.com/vmware-tanzu/carvel-kapp-controller/releases/latest/download/release.yml

kapp deploy -a kadras-repo -y \
    -f https://github.com/kadras-io/kadras-packages/releases/latest/download/package-repository.yml

kapp deploy -a test-dependencies -f test/test-dependencies -y

kubectl create namespace kadras-packages
kapp deploy -a cartographer-blueprints-package -n kadras-packages -y \
  -f https://github.com/kadras-io/cartographer-blueprints/releases/latest/download/metadata.yml \
  -f https://github.com/kadras-io/cartographer-blueprints/releases/latest/download/package.yml

kctrl package install -i cartographer-blueprints \
  -p cartographer-blueprints.packages.kadras.io \
  -v 0.3.0 \
  -n kadras-packages

echo -e "š¦ Deploying Carvel package...\n"

cd package
kctrl dev -f package-resources.yml --local -y
cd ..

echo -e "š® Verifying package..."

status=$(kapp inspect -a cartographer-supply-chains.app --status --json | jq '.Lines[1]' -)
if [[ '"Succeeded"' == ${status} ]]; then
    echo -e "ā The package has been installed successfully.\n"
    exit 0
else
    echo -e "š« Something wrong happened during the installation of the package.\n"
    exit 1
fi
