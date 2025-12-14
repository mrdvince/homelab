.PHONY: recreate iac configure wait-for-nodes bootstrap apply-cilium setup-argocd-repos

# Configuration - matches OPNsense DHCP reservations for MAC addresses
CP_NODES := 10.30.30.141 10.30.30.142 10.30.30.143
WORKER_NODES := 10.30.30.134 10.30.30.135
VIP := 10.30.30.145
CLUSTER_NAME := aion

# Main target that does everything
recreate: iac configure wait-for-nodes bootstrap apply-cilium setup-argocd-repos

# Infrastructure operations with Terragrunt
iac:
	cd ../../proxmox/aion && \
	terragrunt destroy --all --non-interactive -auto-approve && \
	terragrunt apply --all --non-interactive -auto-approve

# Generate and apply Talos configurations
configure:
	talosctl gen config $(CLUSTER_NAME) https://$(VIP):6443 \
	  --output-dir _out \
	  --with-cluster-discovery \
	  --config-patch-control-plane @controlplane.yaml --force

	@for node in $(CP_NODES); do \
		echo "Applying controlplane config to $$node..."; \
		talosctl apply-config --insecure --nodes $$node --file _out/controlplane.yaml; \
	done

	@for node in $(WORKER_NODES); do \
		echo "Applying worker config to $$node..."; \
		talosctl apply-config --insecure --nodes $$node --file _out/worker.yaml; \
	done

	@echo "Configuration applied. Nodes will reboot automatically."
	@mkdir -p ${HOME}/.talos
	cp _out/talosconfig ${HOME}/.talos/config
	talosctl config endpoint $(CP_NODES)
	talosctl config node $(word 1,$(CP_NODES))

# Wait for nodes to be ready after reboot
wait-for-nodes:
	@echo "Waiting for control plane and worker nodes to reboot..."
	@for node in $(CP_NODES) $(WORKER_NODES); do \
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

# Bootstrap the cluster after initial configuration and reboot
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

# Apply Cilium networking manifests
apply-cilium:
	@sleep 1
	@cd ../bootstrap/cilium && helmfile -e aion apply
	@cd ../bootstrap/argocd && helmfile -e aion apply
	@sleep 10
	@echo "Applying Cilium L2 config..."
	@kubectl apply -f cilium-config.yaml
	@sleep 10
	@echo "Cilium manifests applied successfully!"
	@echo "Cluster setup complete."
	@talosctl config node $(CP_NODES) $(WORKER_NODES)

setup-argocd-repos:
	@echo "Setting up ArgoCD repositories with SSH..."
	@chmod +x ./setup-argocd.sh
	@./setup-argocd.sh
	@sleep 30
	@zsh -c "source ~/.zshrc && load_age_secrets && echo \"$$SOPS_AGE_KEY\" | kubectl -n argocd create secret generic age --from-file=key.txt=/dev/stdin"
