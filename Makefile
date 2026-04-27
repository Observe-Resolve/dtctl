# Observe & Resolve Ep. 09 — scenario runner
# Usage: make scenario-1 | scenario-2 | scenario-3

SHELL := /bin/bash
.DEFAULT_GOAL := help
export APP_VERSION ?= v1.0.0

.PHONY: help
help:  ## show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\n\033[1mTargets:\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

.PHONY: deploy
deploy:  ## deploy OTel demo to current kube context
	./demo-app/deploy.sh

.PHONY: baseline
baseline:  ## first apply of dtctl resources at APP_VERSION=v1.0.0
	APP_VERSION=v1.0.0 ./scripts/stamp-version.sh | dtctl apply -f -
	./scripts/freeze-baseline.sh

.PHONY: weaver-check
weaver-check:  ## validate semantic conventions locally
	weaver registry check -r weaver/registry
	weaver registry diff -r weaver/registry --baseline-registry weaver/baselines/main

.PHONY: dtctl-validate
dtctl-validate:  ## validate dtctl manifests (syntactic)
	APP_VERSION=v0.0.0-dev ./scripts/stamp-version.sh | dtctl validate -f -

.PHONY: scenario-1
scenario-1:  ## GREEN: feat cart.size → Weaver ✓ → dtctl apply @ v1.1.0
	./scripts/scenario-1-green.sh

.PHONY: scenario-2
scenario-2:  ## RED: rename customer.tier → Weaver fails → repair suggestion
	./scripts/scenario-2-weaver-save.sh

.PHONY: scenario-3
scenario-3:  ## GUARDIAN: v1.1.2 regression → SRG fails → auto-rollback
	./scripts/scenario-3-srg-gate.sh

.PHONY: clean
clean:  ## tear down cluster + Dynatrace resources
	./demo-app/deploy.sh --destroy || true
	dtctl delete dashboards --selector episode=09 --yes || true
	dtctl delete slos --selector episode=09 --yes || true
	dtctl delete workflows --selector episode=09 --yes || true
