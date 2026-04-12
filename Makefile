SHELL   := /bin/bash
DIR     := mikrotik
SECRETS := $(DIR)/secrets.tfvars.enc

.PHONY: init plan apply fmt validate bootstrap bootstrap-switch

init:
	tofu -chdir=$(DIR) init

plan:
	tofu -chdir=$(DIR) plan -var-file=<(sops -d $(SECRETS))

apply:
	tofu -chdir=$(DIR) apply -var-file=<(sops -d $(SECRETS))

fmt:
	tofu fmt -recursive $(DIR)

validate:
	tofu -chdir=$(DIR) validate

# Run once before init — see README for the full bootstrap procedure.
bootstrap:
	@PASS=$$(sops -d $(SECRETS) | grep router_password | cut -d'"' -f2); \
	 bash scripts/bootstrap-tls.sh 192.168.88.1 admin "$$PASS"

# Run once before first apply targeting the switch.
bootstrap-switch:
	bash scripts/bootstrap-switch.sh
