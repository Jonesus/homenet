SHELL   := /bin/bash
ROUTER  := mikrotik
SECRETS := $(ROUTER)/secrets.tfvars.enc

.PHONY: init plan apply fmt validate bootstrap

init:
	tofu -chdir=$(ROUTER) init

plan:
	tofu -chdir=$(ROUTER) plan -var-file=<(sops -d $(SECRETS))

apply:
	tofu -chdir=$(ROUTER) apply -var-file=<(sops -d $(SECRETS))

fmt:
	tofu fmt -recursive $(ROUTER)

validate:
	tofu -chdir=$(ROUTER) validate

bootstrap:
	@PASS=$$(sops -d $(SECRETS) | grep routeros_password | cut -d'"' -f2); \
	 bash scripts/bootstrap-tls.sh 192.168.88.1 admin "$$PASS"
