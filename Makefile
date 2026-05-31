# =============================================================================
# Makefile — TP IaC + Conteneurisation avancée
# =============================================================================
# Interface utilisateur unique du projet. `make help` liste les cibles.
# =============================================================================

.DEFAULT_GOAL := help
.PHONY: help check info up up-docker up-k8s deploy-docker deploy-k8s deploy demo \
        stop-all start-all destroy-docker destroy-k8s destroy-all \
        terraform-fmt terraform-validate logs-docker logs-k8s

REPO_ROOT := $(shell pwd)
KUBECONFIG := $(REPO_ROOT)/terraform/.ssh/kubeconfig

# Pour les commandes K8s, on exporte KUBECONFIG automatiquement.
export KUBECONFIG

# Affichage couleur (si TERM le supporte)
GREEN  := \033[32m
YELLOW := \033[33m
RESET  := \033[0m

# =============================================================================
# Cibles documentaires
# =============================================================================

help: ## Affiche cette aide
	@echo ""
	@echo "$(GREEN)Cibles disponibles$(RESET) :"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-22s$(RESET) %s\n", $$1, $$2}'
	@echo ""

info: ## Affiche les EIPs et les URLs des 4 stacks
	@echo "=== EIPs ==="
	@cd terraform/envs/docker     && terraform output -raw public_ip 2>/dev/null | xargs -I{} echo "Docker EC2     : {}"; cd $(REPO_ROOT)
	@cd terraform/envs/kubernetes && terraform output -raw control_plane_public_ip 2>/dev/null | xargs -I{} echo "K8s CP         : {}"; cd $(REPO_ROOT)
	@echo ""
	@echo "=== URLs ==="
	@echo "  https://gestion-produits.local       (Docker prod, MySQL)"
	@echo "  https://dev.gestion-produits.local   (Docker dev,  PostgreSQL)"
	@echo "  https://k8s.gestion-produits.local   (K8s    prod, MySQL)"
	@echo "  https://dev.k8s.gestion-produits.local (K8s  dev,  PostgreSQL)"
	@echo ""
	@echo "Login : admin / password"

check: ## Vérifie que les outils nécessaires sont installés
	@command -v terraform >/dev/null || (echo "ERREUR : terraform requis" && exit 1)
	@command -v aws       >/dev/null || (echo "ERREUR : aws cli requis"  && exit 1)
	@command -v docker    >/dev/null || (echo "ERREUR : docker requis"   && exit 1)
	@command -v kubectl   >/dev/null || (echo "ERREUR : kubectl requis"  && exit 1)
	@command -v jq        >/dev/null || (echo "ERREUR : jq requis"       && exit 1)
	@command -v openssl   >/dev/null || (echo "ERREUR : openssl requis"  && exit 1)
	@echo "$(GREEN)Tous les outils sont presents.$(RESET)"

# =============================================================================
# Provisionnement Terraform
# =============================================================================

up-docker: ## Provisionne l'infra Docker (1 EC2 + EIP + SG)
	cd terraform/envs/docker && terraform init && terraform apply -auto-approve

up-k8s: ## Provisionne l'infra Kubernetes (3 EC2 + EFS + SG) + bootstrap k3s
	cd terraform/envs/kubernetes && terraform init && terraform apply -auto-approve
	bash k8s/scripts/bootstrap.sh

up: up-docker up-k8s ## Provisionne les 2 infras + bootstrap

# =============================================================================
# Déploiement applicatif
# =============================================================================

deploy-docker: ## Deploie la stack Docker (Traefik + 4 services)
	bash docker/scripts/deploy.sh

deploy-k8s: ## Deploie l'app sur K8s (overlays prod + dev)
	bash k8s/scripts/deploy.sh

deploy: deploy-docker deploy-k8s ## Deploie les 2 stacks

# =============================================================================
# Test
# =============================================================================

demo: ## Curl les 4 URLs et affiche les HTTP codes
	@DOCKER_IP=$$(cd terraform/envs/docker && terraform output -raw public_ip); \
	K8S_IP=$$(cd terraform/envs/kubernetes && terraform output -raw control_plane_public_ip); \
	echo "Docker prod  : https://gestion-produits.local           = HTTP $$(curl -k -s -o /dev/null -w '%{http_code}' --resolve gestion-produits.local:443:$$DOCKER_IP https://gestion-produits.local/)"; \
	echo "Docker dev   : https://dev.gestion-produits.local       = HTTP $$(curl -k -s -o /dev/null -w '%{http_code}' --resolve dev.gestion-produits.local:443:$$DOCKER_IP https://dev.gestion-produits.local/)"; \
	echo "K8s    prod  : https://k8s.gestion-produits.local       = HTTP $$(curl -k -s -o /dev/null -w '%{http_code}' --resolve k8s.gestion-produits.local:443:$$K8S_IP https://k8s.gestion-produits.local/)"; \
	echo "K8s    dev   : https://dev.k8s.gestion-produits.local   = HTTP $$(curl -k -s -o /dev/null -w '%{http_code}' --resolve dev.k8s.gestion-produits.local:443:$$K8S_IP https://dev.k8s.gestion-produits.local/)"

# =============================================================================
# Logs et debug
# =============================================================================

logs-docker: ## Affiche les logs des conteneurs Docker sur l'EC2
	@DOCKER_IP=$$(cd terraform/envs/docker && terraform output -raw public_ip); \
	ssh -i terraform/.ssh/tp-cont-docker.pem ubuntu@$$DOCKER_IP 'cd /home/ubuntu/tp-cont/docker && docker compose logs --tail=30'

logs-k8s: ## Affiche les pods K8s
	kubectl get pods -A
	@echo ""
	@echo "Pour logs detailles : kubectl -n gestion-produits-{prod|dev} logs <pod-name>"

# =============================================================================
# Qualité / Tests
# =============================================================================

terraform-fmt: ## terraform fmt sur tous les modules / envs
	terraform fmt -recursive terraform/

terraform-validate: ## terraform validate sur les 2 envs
	cd terraform/envs/docker     && terraform validate
	cd terraform/envs/kubernetes && terraform validate

# =============================================================================
# Destruction (attention)
# =============================================================================

destroy-docker: ## Detruit l'infra Docker (EC2 + EIP + VPC)
	cd terraform/envs/docker && terraform destroy -auto-approve

destroy-k8s: ## Detruit l'infra K8s (3 EC2 + EFS + VPC)
	cd terraform/envs/kubernetes && terraform destroy -auto-approve

destroy-all: destroy-docker destroy-k8s ## Detruit toutes les infras
