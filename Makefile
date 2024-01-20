cqlsh:
	podman compose exec -i -t scylladb cqlsh

schema:
	cat schema.cql | podman compose exec scylladb cqlsh

.PHONY: cqlsh schema
