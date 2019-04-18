TOP_DIR=.
OUTPUT_DIR=$(TOP_DIR)/output
README=$(TOP_DIR)/README.md
PROTO_PATH=$(TOP_DIR)/src/priv/proto
PROTO_GEN_PATH=$(TOP_DIR)/src/lib/gen

BUILD_NAME=abt_did_workshop
VERSION=$(strip $(shell cat version))
ELIXIR_VERSION=$(strip $(shell cat .elixir_version))
OTP_VERSION=$(strip $(shell cat .otp_version))

build:
	@echo "Building the software..."
	@rm -rf _build/dev/lib/abt_did_workshop
	@make format
	@cd tools/client; mix compile; mix format;

format:
	@cd src; mix compile; mix format;

init: submodule install dep
	@echo "Initializing the repo..."
	@cd src/assets; npm install; ./node_modules/.bin/webpack;

travis-init: submodule extract-deps
	@echo "Initialize software required for travis (normally ubuntu software)"

install:
	@echo "Install software required for this repo..."
	@mix local.hex --force
	@mix local.rebar --force

dep:
	@echo "Install dependencies required for this repo..."
	@cd src; mix deps.get

pre-build: install dep
	@echo "Running scripts before the build..."
	@cd src/assets; npm install; npm run deploy;
	@cd src; mix phx.digest

post-build:
	@echo "Running scripts after the build is done..."

rebuild-proto: # prepare-vendor-proto
	@protoc -I $(PROTO_PATH)/ --elixir_out=plugins=grpc:$(PROTO_GEN_PATH) $(PROTO_PATH)/*.proto

all: pre-build build post-build

test:
	@echo "Running test suites..."
	@cd src; MIX_ENV=test mix test

doc:
	@echo "Building the documentation..."

precommit: pre-build build post-build test

travis: precommit

travis-deploy:
	@echo "Deploy the software by travis"
	@make build-release
	@make release

clean: clean-api-docs
	@echo "Cleaning the build..."

watch:
	@make build
	@echo "Watching templates and slides changes..."
	@fswatch -o src/ | xargs -n1 -I{} make build

run:
	@echo "Running the software..."
	@cd src; iex -S mix phx.server

submodule:
	@git submodule update --init --recursive

rebuild-deps:
	@cd src; rm -rf mix.lock; rm -rf deps/utility_belt;
	@make dep

include .makefiles/*.mk

.PHONY: build init travis-init install dep pre-build post-build all test doc precommit travis clean watch run bump-version create-pr submodule build-release
