# BOOM-on-NRP deployment shortcuts.
#
# Manifests are split into three groups:
#   k8s/core/           — minimum to run BOOM (mongo + api).
#   k8s/ingestion/      — Kafka + Valkey + consumer/scheduler, for new data.
#   k8s/observability/  — OTel + Prometheus + Grafana + exporters.
#

NS ?= umn-babamul
SECRETS := k8s/secrets.yaml

# Apply every *.yaml in a directory except templates (*.example.yaml).
define apply_dir
	@find $(1) -maxdepth 1 -name '*.yaml' ! -name '*.example.yaml' -print0 \
		| xargs -0 -I {} kubectl apply -n $(NS) -f {}
endef

.PHONY: help deploy deploy-secrets \
        deploy-core deploy-ingestion deploy-observability deploy-all \
        delete-ingestion delete-observability status

help:
	@echo "Targets:"
	@echo "  deploy               Minimal stack for the Boom filter sandbox to work (mongo + boom-api). Alias of deploy-core."
	@echo "  deploy-secrets       Apply k8s/secrets.yaml (explicit; not run by deploy-core)."
	@echo "  deploy-core          Apply k8s/core/   (mongo, boom-api)."
	@echo "  deploy-ingestion     Apply k8s/ingestion/  (valkey, kafka, consumer, scheduler)."
	@echo "  deploy-observability Apply k8s/observability/ (otel, prometheus, grafana, exporters)."
	@echo "  deploy-all           core + ingestion + observability."
	@echo "  delete-core          Tear down the core stack."
	@echo "  delete-ingestion     Tear down the ingestion stack."
	@echo "  delete-observability Tear down the observability stack."
	@echo "  status               kubectl get pods,svc in the namespace."
	@echo ""
	@echo "Namespace: $(NS)  (override with: make deploy NS=other-ns)"

deploy-secrets:
	@test -f $(SECRETS) || { \
		echo "ERROR: $(SECRETS) is missing."; \
		echo "       cp k8s/secrets.example.yaml $(SECRETS) and fill it in."; \
		exit 1; }
	kubectl apply -n $(NS) -f $(SECRETS)

deploy: deploy-core

deploy-core:
	$(call apply_dir,k8s/core)

deploy-ingestion:
	$(call apply_dir,k8s/ingestion)

deploy-observability:
	$(call apply_dir,k8s/observability)

deploy-all: deploy-core deploy-ingestion deploy-observability

delete-core:
	@find k8s/core -maxdepth 1 -name '*.yaml' ! -name '*.example.yaml' -print0 \
		| xargs -0 -I {} kubectl delete -n $(NS) --ignore-not-found -f {}

delete-ingestion:
	@find k8s/ingestion -maxdepth 1 -name '*.yaml' ! -name '*.example.yaml' -print0 \
		| xargs -0 -I {} kubectl delete -n $(NS) --ignore-not-found -f {}

delete-observability:
	@find k8s/observability -maxdepth 1 -name '*.yaml' ! -name '*.example.yaml' -print0 \
		| xargs -0 -I {} kubectl delete -n $(NS) --ignore-not-found -f {}

status:
	kubectl get pods,svc -n $(NS)
