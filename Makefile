.PHONY: all build clean haproxy-telemt-balancer

ROOT := $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))" && pwd)

all: build

build:
	bash "$(ROOT)/build_all.sh"

haproxy-telemt-balancer:
	bash "$(ROOT)/haproxy-telemt-balancer/build.sh"

clean:
	rm -f "$(ROOT)/dist/telemt-haproxy-balancer.sh"
