HOST_PATH := $(shell pwd)
TAG := $(notdir $(HOST_PATH))
CONTAINER_HOME := /home/opam
CONTAINER_PATH := $(CONTAINER_HOME)/app
CONTAINER_PATH_SKIP_DEPEXT := $(CONTAINER_PATH)-skip-depext
VOLUME_NAME := $(TAG)
DBVOLUME_NAME := $(TAG)-db
DOCKER := docker run --network messaging --name $(TAG) --rm -it -p 5500:5500 -v $(HOME)/.ssh:$(CONTAINER_HOME)/.ssh -v $(VOLUME_NAME):$(CONTAINER_PATH)/_build -v $(HOME)/.config/nvim:$(CONTAINER_HOME)/.config/nvim -v $(HOST_PATH):$(CONTAINER_PATH) -w $(CONTAINER_PATH) $(TAG)
DOCKER_NO_RM := docker run --network messaging --name $(TAG) -it -p 5500:5500 -v $(HOME)/.ssh:$(CONTAINER_HOME)/.ssh -v $(VOLUME_NAME):$(CONTAINER_PATH)/_build -v $(HOME)/.config/nvim:$(CONTAINER_HOME)/.config/nvim -v $(HOST_PATH):$(CONTAINER_PATH) -w $(CONTAINER_PATH) $(TAG)
DOCKER_SKIP_DEPEXT := docker run --network messaging --name $(TAG) --rm -it -p 5500:5500 -v $(HOME)/.ssh:$(CONTAINER_HOME)/.ssh -v $(VOLUME_NAME):$(CONTAINER_PATH_SKIP_DEPEXT)/_build -v $(HOME)/.config/nvim:$(CONTAINER_HOME)/.config/nvim -v $(HOST_PATH):$(CONTAINER_PATH_SKIP_DEPEXT) -w $(CONTAINER_PATH_SKIP_DEPEXT) $(TAG)

.PHONY: default
default: watch

.PHONY: shell
shell:
	$(DOCKER) bash

duniverse:
	$(DOCKER_SKIP_DEPEXT) opam monorepo pull

.PHONY: run
run:
	$(DOCKER) dune exec src/main.exe

.PHONY: volume
volume:
	@if ! docker volume inspect $(VOLUME_NAME) >/dev/null 2>&1; then \
		docker volume create $(VOLUME_NAME); \
	fi

.PHONY: db-volume
db-volume:
	@if ! docker volume inspect $(DBVOLUME_NAME) >/dev/null 2>&1; then \
		docker volume create $(DBVOLUME_NAME); \
	fi

.PHONY: watch
watch: install-deps
	dune build bin/main.exe -w

.PHONY: watch-all
watch-all: install-deps
	dune build @all -w

.PHONY: exe
exe:
	./scripts/dev-run.sh ./_build/default/bin/main.exe

.PHONY: install-deps
install-deps:
	opam install . --deps-only

.PHONY: nvim
nvim:
	# nvim -c "terminal make exe" -c "terminal make watch" -c 'vsplit' -c 'split' -c 'terminal tail stdout -F' -c 'split' -c 'terminal tail stderr -F' -c 'wincmd h' -c 'Oil' ; exec bash -l
	opam-2.4 exec -- nvim -c 'vsplit' -c "terminal watch 'make test'" -c 'split' -c 'terminal tail stdout.message_processor -F' -c 'split' -c 'terminal tail stderr.message_processor -F' -c 'wincmd h' -c 'Oil' ; exec bash -l

.PHONY: start
start: volume
	# $(DOCKER) dune build web/main.bc.js
	$(DOCKER) make nvim

.PHONY: start-db
start-db: db-volume
	# $(DOCKER) dune build web/main.bc.js
	docker run --name $(TAG)-db -it \
		-e POSTGRES_DB=messaging_service \
		-e POSTGRES_USER=messaging_user \
		-e POSTGRES_PASSWORD=messaging_password \
		-e POSTGRES_INITDB_ARGS="--auth-host=md5" \
		-p 5432:5432 \
		--network messaging \
		-v $(DBVOLUME_NAME):/var/lib/postgresql/data \
		-v ./migrations/001_init.sql:/docker-entrypoint-initdb.d/init.sql \
		--health-cmd='pg_isready -U messaging_user -d messaging_service' \
		--health-interval=10s \
		--health-timeout=5s \
		--health-retries=5 \
		postgres:15-alpine

.PHONY: start-no-rm
start-no-rm: volume
	$(DOCKER_NO_RM) make nvim

.PHONY: resume
resume: volume
	docker start -ai $(TAG)

.PHONY: stop
stop:
	docker stop $(TAG)

.PHONY: build
build: duniverse
	$(DOCKER) dune build

.PHONY: lock
lock:
	$(DOCKER) opam monorepo lock

.PHONY: clean
clean:
	-@$(DOCKER_SKIP_DEPEXT) dune clean

.PHONY: distclean
distclean: stop clean
	@rm -rf _opam
	@$(DOCKER_SKIP_DEPEXT) rm -rf duniverse
	@docker volume rm $(VOLUME_NAME)

.PHONY: docker-lazygit
docker-lazygit:
	docker build -t lazygit docker/lazygit

.PHONY: docker-ocamlformat
docker-ocamlformat:
	docker build -t ocamlformat docker/ocamlformat

.PHONY: docker
docker: docker-ocamlformat docker-lazygit
	docker build --build-arg TAG=$(TAG) -t $(TAG) -f docker/app/Dockerfile .

.PHONY: test
test:
	./scripts/test.sh
