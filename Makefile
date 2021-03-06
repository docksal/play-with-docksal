DOCKER ?= docker

FROM ?= docker:18.09.2-dind
TAG ?= pure

REPO = docksal/play-with-docksal
NAME = docksal-dind

.EXPORT_ALL_VARIABLES:

.PHONY: build test push shell run start stop logs clean release

build:
	$(DOCKER) build -t $(REPO):$(TAG) --build-arg FROM=$(FROM) -f ./dind/Dockerfile.$(TAG) ./dind

test:
	IMAGE=$(REPO):$(TAG) NAME=$(NAME) VERSION=$(VERSION) ./tests/test.bats

push:
	$(DOCKER) push $(REPO):$(TAG)

shell: clean
	$(DOCKER) run --rm --name $(NAME) -it $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG) /bin/bash

run: clean
	$(DOCKER) run --rm --name $(NAME) -it $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG)

start: clean
	$(DOCKER) run -d --name $(NAME) $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG)

exec:
	$(DOCKER) exec $(NAME) /bin/bash -c "$(CMD)"

stop:
	$(DOCKER) stop $(NAME)

logs:
	$(DOCKER) logs $(NAME)

clean:
	$(DOCKER) rm -f $(NAME) >/dev/null 2>&1 || true

release:
	@scripts/release.sh

default: build
