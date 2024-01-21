help: #: Show this help message
	@awk '/^[A-Za-z_ -]*:.*#:/ {printf("%c[1;32m%-15s%c[0m", 27, $$1, 27); for(i=3; i<=NF; i++) { printf("%s ", $$i); } printf("\n"); }' Makefile* | sort

cqlsh: #: Invoke cql inside the scylladb container
	podman compose exec -i -t scylladb cqlsh

schema: #: Install the schema into the scylladb
	cat schema.cql | podman compose exec scylladb cqlsh

serve: #: Star the service
	@./run serve.rb

deps: #: Install the dependencies and write the classpath file
	@./deps

.PHONY: help cqlsh schema serve deps
