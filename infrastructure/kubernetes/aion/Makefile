.PHONY: recreate iac iac-cp iac-workers configure wait-for-nodes bootstrap apply-cilium setup-argocd-repos upload-config fetch-config gen-config

# configuration, matches opnsense dhcp reservations for mac addresses
CP_NODES := 10.30.30.141 10.30.30.142 10.30.30.143
WORKER_NODES :=
VIP := 10.30.30.145
CLUSTER_NAME := aion

# network config, must not overlap with other clusters for mesh
POD_SUBNET := 10.244.0.0/17
SERVICE_SUBNET := 10.96.0.0/17
NIC := enp6s18

# paths
PROXMOX_BASE := ../../proxmox/aion

# s3 state store for talos configs
S3_ENDPOINT := https://garage-s3.home.mrdvince.me
S3_BUCKET := talos-state

# all nodes
ALL_NODES := $(CP_NODES) $(WORKER_NODES)

# main target that does everything
recreate: iac configure wait-for-nodes bootstrap apply-cilium setup-argocd-repos

# infrastructure operations with terragrunt
iac: iac-cp iac-workers

iac-cp:
	cd $(PROXMOX_BASE)/cp && \
	terragrunt destroy --non-interactive -auto-approve && \
	terragrunt apply --non-interactive -auto-approve

iac-workers:
ifneq ($(strip $(WORKER_NODES)),)
	cd $(PROXMOX_BASE)/nodes && \
	terragrunt destroy --non-interactive -auto-approve && \
	terragrunt apply --non-interactive -auto-approve
endif

# generate controlplane.yaml from template
gen-config:
	@( \
		export VIP="$(VIP)" POD_SUBNET="$(POD_SUBNET)" SERVICE_SUBNET="$(SERVICE_SUBNET)" NIC="$(NIC)"; \
		export CERT_SANS="$$(printf '      - %s\n' $(CP_NODES))"; \
		envsubst < controlplane.yaml.tmpl \
	) > controlplane.yaml
	@echo "Generated controlplane.yaml"

# generate and apply talos configurations
configure: gen-config
	talosctl gen config $(CLUSTER_NAME) https://$(VIP):6443 \
	  --output-dir _out \
	  --with-cluster-discovery \
	  --config-patch-control-plane @controlplane.yaml --force

	@for node in $(CP_NODES); do \
		echo "Applying controlplane config to $$node..."; \
		talosctl apply-config --insecure --nodes $$node --file _out/controlplane.yaml; \
	done

ifneq ($(strip $(WORKER_NODES)),)
	@for node in $(WORKER_NODES); do \
		echo "Applying worker config to $$node..."; \
		talosctl apply-config --insecure --nodes $$node --file _out/worker.yaml; \
	done
endif

	@echo "Configuration applied. Nodes will reboot automatically."
	@$(MAKE) upload-config
	@$(MAKE) fetch-config

# wait for nodes to be ready after reboot
wait-for-nodes:
	@echo "Waiting for nodes to reboot..."
	@for node in $(ALL_NODES); do \
		echo "Checking node $$node..."; \
		for i in $$(seq 1 60); do \
			if talosctl --nodes $$node -e $$node version > /dev/null 2>&1; then \
				echo "Node $$node is ready!"; \
				break; \
			fi; \
			if [ $$i -eq 60 ]; then \
				echo "Timed out waiting for node $$node"; \
				exit 1; \
			fi; \
			echo "Node $$node not ready yet. Waiting 5 seconds..."; \
			sleep 5; \
		done; \
	done
	@echo "All nodes are ready!"

# bootstrap the cluster after initial configuration and reboot
bootstrap:
	talosctl bootstrap
	@echo "Talos cluster bootstrap complete!"
	@echo "Waiting for Kubernetes API to be ready..."
	@talosctl kubeconfig -n $(word 1,$(CP_NODES)) --force
	@for i in $$(seq 1 30); do \
		if kubectl get nodes > /dev/null 2>&1; then \
			echo "Kubernetes API is ready!"; \
			break; \
		fi; \
		if [ $$i -eq 30 ]; then \
			echo "Timed out waiting for Kubernetes API"; \
			exit 1; \
		fi; \
		echo "Kubernetes API not ready yet. Waiting 10 seconds..."; \
		sleep 10; \
	done
	@echo "Kubernetes API is now available."

# apply cilium networking manifests
apply-cilium:
	@sleep 1
	@cd ../bootstrap/cilium && helmfile -e aion apply
	@echo "waiting for cilium l2 crds..."
	@for i in $$(seq 1 30); do \
		if kubectl get crd ciliuml2announcementpolicies.cilium.io >/dev/null 2>&1; then \
			echo "cilium crds ready"; \
			break; \
		fi; \
		if [ $$i -eq 30 ]; then \
			echo "timed out waiting for cilium crds"; \
			exit 1; \
		fi; \
		sleep 5; \
	done
	@echo "applying cilium l2 config..."
	@kubectl apply -f cilium-config.yaml
	@echo "cilium manifests applied"
	@talosctl config node $(ALL_NODES)

setup-argocd-repos:
	@echo "Setting up ArgoCD..."
	@cd ../bootstrap/argocd && helmfile -e aion apply
	@sleep 10
	@echo "Setting up ArgoCD repositories with SSH..."
	@chmod +x ./setup-argocd.sh
	@./setup-argocd.sh
	@sleep 30
	@zsh -c "source ~/.zshrc && load_age_secrets && echo \"$$SOPS_AGE_KEY\" | kubectl -n argocd create secret generic age --from-file=key.txt=/dev/stdin"
	@echo "Cluster setup complete."

upload-config:
	@echo "Uploading talos configs to S3..."
	@aws s3 cp _out/talosconfig s3://$(S3_BUCKET)/$(CLUSTER_NAME)/talosconfig --endpoint-url $(S3_ENDPOINT)
	@aws s3 cp _out/controlplane.yaml s3://$(S3_BUCKET)/$(CLUSTER_NAME)/controlplane.yaml --endpoint-url $(S3_ENDPOINT)
ifneq ($(strip $(WORKER_NODES)),)
	@aws s3 cp _out/worker.yaml s3://$(S3_BUCKET)/$(CLUSTER_NAME)/worker.yaml --endpoint-url $(S3_ENDPOINT)
endif
	@echo "Configs uploaded to s3://$(S3_BUCKET)/$(CLUSTER_NAME)/"

fetch-config:
	@echo "Fetching talos config from S3..."
	@mkdir -p ${HOME}/.talos
	@aws s3 cp s3://$(S3_BUCKET)/$(CLUSTER_NAME)/talosconfig ${HOME}/.talos/config --endpoint-url $(S3_ENDPOINT)
	@talosctl config endpoint $(CP_NODES)
	@talosctl config node $(word 1,$(CP_NODES))
	@echo "Config installed to ~/.talos/config"
