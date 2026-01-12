package securedgateways

##
## Helpers / Guards
##

is_gateway(g) {
    g.kind == "Gateway"
    g.apiVersion == "networking.istio.io/v1beta1"
    g.spec
    g.spec.servers
}

servers(g) := g.spec.servers {
    is_gateway(g)
}

is_http(protocol) {
    protocol == "HTTP"
}

is_http(protocol) {
    protocol == "HTTP2"
}

contains(arr, val) {
    arr[_] == val
}

tls_protocol_violation_msg(parameterName, options) = msg {
    msg := sprintf("TLS %v for HTTPS must be set to one of the following: %v", [parameterName, options])
}

##
## Policies
##

# Ensure HTTP is only used for redirect
violation[{"msg": msg}] {
	gateway := input.review.object
	is_gateway(gateway)

	server := servers(gateway)[_]
	server.port
	server.port.protocol
	is_http(server.port.protocol)

	server.tls
	not server.tls.httpsRedirect

	msg := "HTTP servers can only be used for HTTPS redirect. Please ensure that httpsRedirect is set to true in the TLS settings."
}

# Ensure minimum TLS version is set
violation[{"msg": msg}] {
	gateway := input.review.object
	is_gateway(gateway)

	server := servers(gateway)[_]
	server.port.protocol == "HTTPS"

	server.tls
	not server.tls.minProtocolVersion

	msg := tls_protocol_violation_msg("minProtocolVersion", input.parameters.minTLSVersions)
}

# Ensure minimum TLS version is approved
violation[{"msg": msg}] {
	gateway := input.review.object
	is_gateway(gateway)

	server := servers(gateway)[_]
	server.port.protocol == "HTTPS"

	server.tls
	server.tls.minProtocolVersion
	not contains(input.parameters.minTLSVersions, server.tls.minProtocolVersion)

	msg := tls_protocol_violation_msg("minProtocolVersion", input.parameters.minTLSVersions)
}

# Ensure maximum TLS version is set
violation[{"msg": msg}] {
	gateway := input.review.object
	is_gateway(gateway)

	server := servers(gateway)[_]
	server.port.protocol == "HTTPS"

	server.tls
	not server.tls.maxProtocolVersion

	msg := tls_protocol_violation_msg("maxProtocolVersion", input.parameters.maxTLSVersions)
}

# Ensure maximum TLS version is approved
violation[{"msg": msg}] {
	gateway := input.review.object
	is_gateway(gateway)

	server := servers(gateway)[_]
	server.port.protocol == "HTTPS"

	server.tls
	server.tls.maxProtocolVersion
	not contains(input.parameters.maxTLSVersions, server.tls.maxProtocolVersion)

	msg := tls_protocol_violation_msg("maxProtocolVersion", input.parameters.maxTLSVersions)
}

# Ensure only approved CipherSuites are used
violation[{"msg": msg}] {
	gateway := input.review.object
	is_gateway(gateway)

	server := servers(gateway)[_]
	server.port.protocol == "HTTPS"

	server.tls
	server.tls.cipherSuites

	approved := {cs | cs := input.parameters.approvedCipherSuites[_]}
	used := {cs |
			server.tls.cipherSuites
			cs := server.tls.cipherSuites[_]
	}

	count(used - approved) > 0

	msg := sprintf("Only the following CipherSuites may be used: %v", [approved])
}

# Ensure CipherSuites are set and not empty
violation[{"msg": msg}] {
	gateway := input.review.object
	is_gateway(gateway)

	server := servers(gateway)[_]
	server.port.protocol == "HTTPS"

	server.tls
	server.tls.cipherSuites

	suites := [cs |
			server.tls.cipherSuites
			cs := server.tls.cipherSuites[_]
	]

	count(suites) == 0

	msg := sprintf("CipherSuites must be defined from the following: %v", [input.parameters.approvedCipherSuites])
}

# Ensure TLS mode is set
violation[{"msg": msg}] {
	gateway := input.review.object
	is_gateway(gateway)

	server := servers(gateway)[_]
	server.port.protocol == "HTTPS"

	server.tls
	not server.tls.mode

	msg := sprintf("TLS mode must be set to one of the following: %v", [input.parameters.tlsModes])
}

# Ensure TLS mode is approved
violation[{"msg": msg}] {
    gateway := input.review.object
    is_gateway(gateway)

    server := servers(gateway)[_]
    server.port.protocol == "HTTPS"

    server.tls
    server.tls.mode
    not contains(input.parameters.tlsModes, server.tls.mode)

    msg := sprintf("TLS mode must be set to one of the following: %v", [input.parameters.tlsModes])
}