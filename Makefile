# IBM Confidential
# OCO Source Materials
# (C) Copyright IBM Corporation 2018 All Rights Reserved
# The source code for this program is not published or otherwise divested of its trade secrets, irrespective of what has been deposited with the U.S. Copyright Office.

include build/Configfile

# CICD BUILD HARNESS
####################
GITHUB_USER := $(shell echo $(GITHUB_USER) | sed 's/@/%40/g')

.PHONY: default
default:: init;

.PHONY: init\:
init::
	@mkdir -p variables
ifndef GITHUB_USER
	$(info GITHUB_USER not defined)
	exit -1
endif
	$(info Using GITHUB_USER=$(GITHUB_USER))
ifndef GITHUB_TOKEN
	$(info GITHUB_TOKEN not defined)
	exit -1
endif

-include $(shell curl -H 'Authorization: token ${GITHUB_TOKEN}' -H 'Accept: application/vnd.github.v4.raw' -L https://api.github.com/repos/open-cluster-management/build-harness-extensions/contents/templates/Makefile.build-harness-bootstrap -o .build-harness-bootstrap; echo .build-harness-bootstrap)


.PHONY: all lint test dependencies build image rhel-image manager run deploy install \
fmt vet generate docker-push docker-push-rhel

all: test manager

lint:
	@echo "Linting disabled."

# Run tests
test: generate fmt vet manifests
	curl -sL https://go.kubebuilder.io/dl/2.0.0-alpha.1/${GOOS}/${GOARCH} | tar -xz -C /tmp/

	sudo mv /tmp/kubebuilder_2.0.0-alpha.1_${GOOS}_${GOARCH} /usr/local/kubebuilder
	go test ./pkg/... ./cmd/... -v -coverprofile cover.out

dependencies:
	curl https://raw.githubusercontent.com/golang/dep/master/install.sh | sh
	# export PATH=$(PATH):/$(GOPATH)/bin
	dep ensure

build:
	CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) go build -a -tags netgo -o ./iam-policy_$(GOARCH) ./cmd/manager

image:
	$(eval DOCKER_BUILD_OPTS := '--build-arg "VCS_REF=$(GIT_COMMIT)" \
		--build-arg "VCS_URL=$(GIT_REMOTE_URL)" \
		--build-arg "IMAGE_NAME=$(DOCKER_IMAGE)" \
		--build-arg "IMAGE_DESCRIPTION=$(IMAGE_DESCRIPTION)" \
		--build-arg "SUMMARY=$(SUMMARY)" \
		--build-arg "GOARCH=$(GOARCH)"')
	@make DOCKER_BUILD_OPTS=$(DOCKER_BUILD_OPTS) docker:build
	@make docker:tag

rhel-image:
	docker tag $(DOCKER_REGISTRY)/$(DOCKER_NAMESPACE)/$(DOCKER_IMAGE):$(DOCKER_BUILD_TAG) $(DOCKER_REGISTRY)/$(DOCKER_NAMESPACE)/$(DOCKER_IMAGE):$(DOCKER_BUILD_TAG_RHEL)

# Run against the configured Kubernetes cluster in ~/.kube/config
run: generate fmt vet
	go run ./cmd/manager/main.go

# Install CRDs into a cluster
install: manifests
	kubectl apply -f config/crds

# Deploy controller in the configured Kubernetes cluster in ~/.kube/config
deploy: manifests
	kubectl apply -f config/crds
	kustomize build config/default | kubectl apply -f -

# Generate manifests e.g. CRD, RBAC etc.
manifests:
	go run vendor/sigs.k8s.io/controller-tools/cmd/controller-gen/main.go all

# Run go fmt against code
fmt:
	go fmt ./pkg/... ./cmd/...

# Run go vet against code
vet:
	go vet ./pkg/... ./cmd/...

# Generate code
generate:
	go generate ./pkg/... ./cmd/...

# Push the docker image
docker-push:
	@make docker:push
ifneq ($(RETAG),)
	$(eval RELEASE := $(DOCKER_REGISTRY)/$(DOCKER_NAMESPACE)/$(DOCKER_IMAGE):$(SEMVERSION))
	docker tag $(DOCKER_REGISTRY)/$(DOCKER_NAMESPACE)/$(DOCKER_IMAGE):$(DOCKER_BUILD_TAG) $(RELEASE)
	@make DOCKER_URI=$(RELEASE) docker:push
	@echo "Retagged image as $(RELEASE) and pushed to $(DOCKER_REGISTRY)"
endif

docker-push-rhel:
	$(eval RHEL_IMAGE := $(DOCKER_REGISTRY)/$(DOCKER_NAMESPACE)/$(DOCKER_IMAGE):$(DOCKER_BUILD_TAG_RHEL))
	@make DOCKER_URI=$(RHEL_IMAGE) docker:push
ifneq ($(RETAG),)
	$(eval RELEASE := $(DOCKER_REGISTRY)/$(DOCKER_NAMESPACE)/$(DOCKER_IMAGE):$(SEMVERSION)-rhel)
	docker tag $(DOCKER_REGISTRY)/$(DOCKER_NAMESPACE)/$(DOCKER_IMAGE):$(DOCKER_BUILD_TAG_RHEL) $(RELEASE)
	@make DOCKER_URI=$(RELEASE) docker:push
	@echo "Retagged image as $(RELEASE) and pushed to $(DOCKER_REGISTRY)"
endif
