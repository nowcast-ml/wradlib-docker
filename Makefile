.DEFAULT_GOAL:= help

PWD:=$(shell pwd)

GITHOOKSDIR = $(shell git rev-parse --git-dir)/hooks
GITHOOKS = $(patsubst %.sh, $(GITHOOKSDIR)/%, $(notdir $(wildcard scripts/githooks/*.sh)))

$(GITHOOKSDIR)/%: scripts/githooks/%.sh
	ln -s -f "${PWD}/$<" $@

.PHONY: githooks
githooks: $(GITHOOKS) ## Register git hooks

.PHONY: build
build: ## Build local docker development image
	docker build --tag nowcast/wradlib-docker:latest --target=image .

.PHONY: run
run: build ## Run local docker image
	docker run --rm -it nowcast/wradlib-docker:latest /bin/bash

.PHONY: help
help: ## Display this message
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "%-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
