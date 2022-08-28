#!/usr/bin/env bash

echo "While protean-gitops can be used without docker, we do want it for default container operations here."
echo "Podman is more strict on registry, so if swapping out docker for podman, note that TLS will need to be set up for the registry for podman to push as is."
echo
echo "The main program proteus will install cosign and syft if not found as well, but we do want to go ahead and install them and generate a cosign key."

cosigninstall () {
  wget "https://github.com/sigstore/cosign/releases/download/v1.6.0/cosign-linux-amd64" && mv cosign-linux-amd64 /usr/local/bin/cosign && chmod +x /usr/local/bin/cosign
}

which syft || curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
which cosign || cosigninstall
cp proteus /usr/local/sbin/
chmod +x /usr/local/sbin/proteus
mkdir -p /opt/protean-gitops
cd /opt/protean-gitops
ls cosign.key || cosign generate-key-pair

echo
echo "The design pattern is to use anacron or cron to schedule proteus SCM polling, however it can be scheduled however you like!"
echo "Enjoy!"

