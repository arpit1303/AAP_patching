SHELL := /bin/bash
export ANSIBLE_LOCAL_TEMP ?= /tmp/ansible-local
export ANSIBLE_REMOTE_TEMP ?= /tmp/ansible-remote

.PHONY: deps validate bootstrap-local

deps:
	./scripts/setup_local_demo.sh

validate:
	ansible-playbook --syntax-check bootstrap_tam_day_assets.yml
	ansible-playbook --syntax-check env_slack_configure_aap_credential.yml
	ansible-playbook --syntax-check env_slack_validate_webhook.yml

bootstrap-local:
	@test -n "$$AAP_URL" || (echo "Set AAP_URL" && exit 1)
	@test -n "$$AAP_USER" || (echo "Set AAP_USER" && exit 1)
	@test -n "$$AAP_PASS" || (echo "Set AAP_PASS" && exit 1)
	ansible-playbook bootstrap_tam_day_assets.yml \
		-e "aap_url=$$AAP_URL" \
		-e "aap_user=$$AAP_USER" \
		-e "aap_pass=$$AAP_PASS"
