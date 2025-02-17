package restricthostnames

# Ensure that the normalization function correctly normalizes without the loss of data.
test_normalize_hosts {
	hosts := json.unmarshal(`[{"host": "www.ssc-spc.gc.ca","path": "/"}, {"host": "example.acme.com","path":"/acme/example"}, {"host": "example.acme.com","path":"/acme/OTHER"}, {"host": "example.ca","path":""}]`)

	expected_hosts := [{"host": "www.ssc-spc.gc.ca", "path": "/"}, {"host": "example.acme.com", "path": "/acme/example"}, {"host": "example.acme.com", "path": "/acme/other"}, {"host": "example.ca", "path": ""}]

	expected_hosts == normalize_hosts(hosts)
}

# Ensures that prefix allowance works correctly.
test_prefix_pass {
	namespaces := {"test-prefix-pass": {
		"apiVersion": "v1",
		"kind": "Namespace",
		"metadata": {
			"annotations": {"ingress.ssc-spc.gc.ca/allowed-hosts": `[{"host": "example.ca","path":"/"}]`},
			"name": "test-prefix-pass",
		},
	}}

	host := "example.ca"
	path := "/pass"

	is_allowed(host, path) with input.review.object.metadata.namespace as "test-prefix-pass" with data.inventory.cluster.v1.Namespace as namespaces
}
