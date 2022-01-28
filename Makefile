SHELL := /usr/bin/env bash

# Vars Start
ARTIFACT_DIR = artifacts
TARGET_DIR = target
PROJECT = github-workflow-example
PYTHON = $(PROJECT)/bin/python -m
PIP = $(PROJECT)/bin/pip3
# Vars End


# Remote Env Vars Start
S3_BUCKET := ""
s3-bucket-info:
	@echo "   "
	@echo "    S3 Bucket: "$(S3_BUCKET)
# Remote Env Vars End


# Versioning Start
LATEST_TAG := 0.0.0
ifneq ('$(shell git tag -l)','')
	LATEST_TAG := $(shell git describe --abbrev=0 --tags)
endif

NEXT_VERSION = $($(PYTHON) pysemver nextver $(LATEST_TAG) minor)
CURRENT_ARTIFACT_VERSION := $(PROJECT)-$(LATEST_TAG).zip
NEXT_ARTIFACT_VERSION := $(PROJECT)-$(NEXT_VERSION).zip

current-release-version:
	@echo "$(CURRENT_ARTIFACT_VERSION)"

next-release-version:
	@echo $(NEXT_ARTIFACT_VERSION)
# Versioning End


# Utils Start
clean:
	@echo " "
	@echo "Cleaning up"
	rm -rf __pycache__ */**.pyc .pytest_cache  $(TARGET_DIR) $(ARTIFACT_DIR)

set-up:
	@echo " "
	@echo "Setting up environment"
    ifeq ('$(shell type -P python)','')
	    $(error python interpreter: 'python' not found!)
    endif
	@python -m venv $(PROJECT)
	ls -al
	$(PIP) install -q --upgrade pip
	$(PIP) install -q -r requirements.txt -r requirements-test.txt -r requirements-build.txt;
# Utils End


# Testing Start
.PHONY: auto-format
auto-format: set-up
	@echo " "
	@echo "Formatting python code"
	$(PYTHON) black handler.py
	$(PYTHON) flake8 handler.py tests

security-checks:
	$(PYTHON) safety check
	$(PYTHON) bandit -r handler.py

.PHONY: test
test: clean set-up auto-format security-checks
	@echo " "
	@echo "Running tests.."
	$(PYTHON) pytest
# Testing End


# Packing Start
.PHONY: package
package: clean
	@echo " "
	@echo "Building deployment artifacts"
	@mkdir $(TARGET_DIR)
	@mkdir $(ARTIFACT_DIR)
	@cp -r handler.py $(TARGET_DIR)
	@cp -r logging.conf $(TARGET_DIR)
	$(PIP) install -q -r requirements.txt -t $(TARGET_DIR)/
	@cd $(TARGET_DIR) && zip -q -r ../$(ARTIFACT_DIR)/$(NEXT_ARTIFACT_VERSION) .
	@openssl dgst -sha256 -binary $(ARTIFACT_DIR)/$(NEXT_ARTIFACT_VERSION) | openssl enc -base64 > $(ARTIFACT_DIR)/$(NEXT_ARTIFACT_VERSION).base64sha256
	@echo "    "
	@echo "Latest release artifacts:"
	@echo "    "`ls $(ARTIFACT_DIR)`
# Packing End


# Releasing Start
push-latest-release-tag:
	@echo " "
	@echo "Pushing release tag to git"
	@git tag -a $(NEXT_VERSION) -m "Releasing  $(NEXT_VERSION) "
	@git push origin --tags

bundle:
	@echo " "
	@echo "Building deployment artifacts"
	@mkdir $(TARGET_DIR)
	@mkdir $(ARTIFACT_DIR)
	@printf $(LATEST_TAG) > $(ARTIFACT_DIR)/presigned_url_latest.version
	@cp -r handler.py $(TARGET_DIR)
	@cp -r logging.conf $(TARGET_DIR)
	$(PIP) install -q -r requirements.txt -t $(TARGET_DIR)/
	@cd $(TARGET_DIR) && zip -q -r ../$(ARTIFACT_DIR)/$(CURRENT_ARTIFACT_VERSION) .
	@openssl dgst -sha256 -binary $(ARTIFACT_DIR)/$(CURRENT_ARTIFACT_VERSION) | openssl enc -base64 > $(ARTIFACT_DIR)/$(CURRENT_ARTIFACT_VERSION).base64sha256


push-s3: s3-bucket-info
	@echo " "
	@echo "Uploading artifact to s3 "$(S3_BUCKET)
	@aws s3 cp $(ARTIFACT_DIR)/$(NEXT_ARTIFACT_VERSION) s3://$(S3_BUCKET)/$(PROJECT)/$(NEXT_ARTIFACT_VERSION) --acl=bucket-owner-full-control
	@aws s3 cp $(ARTIFACT_DIR)/$(NEXT_ARTIFACT_VERSION).base64sha256 s3://$(S3_BUCKET)/$(PROJECT)/$(NEXT_ARTIFACT_VERSION).base64sha256 --acl=bucket-owner-full-control --content-type=text/plain
# Releasing End


# Create Lambda Start
deploy-lambda:
	@aws iam create-role --role-name lambda-role --assume-role-policy-document file://role.json
	@aws lambda create-function --function-name $(PROJECT) --runtime python3.8 --handler handler.handle --zip-file $(ARTIFACT_DIR)/$(NEXT_ARTIFACT_VERSION)
# Create Lambda End