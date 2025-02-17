package restricthostnames

# Annotation which contains JSON information about exempted Hosts and Paths
# JSON structure is as follows:
# array(
#   object(
#     host: string,
#     path: string
#   )
# )
annotation := "ingress.ssc-spc.gc.ca/allowed-hosts"

# Allowed hosts scraped from the above annotation.
allowedHosts := hosts {
	json.is_valid(data.inventory.cluster.v1.Namespace[input.review.object.metadata.namespace].metadata.annotations[annotation])
	hosts := normalize_hosts(json.unmarshal(data.inventory.cluster.v1.Namespace[input.review.object.metadata.namespace].metadata.annotations[annotation]))
}

# Normalizes the objects for easier logic by lowercasing the path.
normalize_hosts(hosts) = normalized_hosts {
	normalized_hosts := [host |
		current_host_object := hosts[_]
		host := {"host": current_host_object.host, "path": lower(current_host_object.path)}
	]
}

# Exemptions for hosts passed in via the configuration of the Policy
is_exempt(host) {
	exemption := input.parameters.exemptions[_]
	glob.match(exemption, [], host)
}

# Exemptions for hosts within the namespace
is_exempt(host) {
	glob.match(concat(".", ["*", input.review.object.metadata.namespace, "svc**"]), [], host)
}

# Host and path is permitted
is_allowed(host, path) {
	allowedHost := allowedHosts[_]

	host == allowedHost.host
	startswith(lower(path), allowedHost.path)
}

# Host and path is permitted for VirtualServices regex match
# Regex must start with an allowed path in the form of "^$PATH*"
is_allowed(host, path) {
	allowedHost := allowedHosts[_]

	host == allowedHost.host
	startswith(path, concat("", ["^", allowedHost.path]))
}

# Determines if a host and path combination is invalid and returns a concatenated response.
is_invalid(host, path) = invalid {
	# Check if the hostname is exempt
	not is_exempt(host)

	# Check if the hostname is allowed
	not is_allowed(host, path)

	invalid := concat("", [host, path])
}

get_paths = paths {
	paths := ({path | path := input.review.object.spec.rules[_].http.paths[_].path} | ({path | path := input.review.object.spec.http[_].match[_].uri.exact} | {path | path := input.review.object.spec.http[_].match[_].uri.prefix})) | {path | path := input.review.object.spec.http[_].match[_].uri.regex}
	count(paths) > 0
}

get_paths = paths {
	count(({path | path := input.review.object.spec.rules[_].http.paths[_].path} | ({path | path := input.review.object.spec.http[_].match[_].uri.exact} | {path | path := input.review.object.spec.http[_].match[_].uri.prefix})) | {path | path := input.review.object.spec.http[_].match[_].uri.regex}) == 0
	paths := ["/"]
}

get_hosts = hosts {
	hosts := ({host | host := input.review.object.spec.rules[_].host} | {host | host := input.review.object.spec.hosts[_]}) | {host | host := input.review.object.spec.host}
	count(hosts) > 0
}

get_hosts = hosts {
	count(({host | host := input.review.object.spec.rules[_].host} | {host | host := input.review.object.spec.hosts[_]}) | {host | host := input.review.object.spec.host}) == 0
	hosts := [""]
}

# Ingress, VirtualService, or DestinationRule must have valid hostpaths
violation[{"msg": msg}] {
	kind := input.review.kind.kind
	re_match("^(Ingress|VirtualService|DestinationRule)$", kind)
	re_match("^(networking.k8s.io|networking.istio.io)$", input.review.kind.group)

	# Gather all invalid host and path combinations
	invalid_hostpaths := {hostpath |
		host := get_hosts()[_]
		path := get_paths()[_]

		hostpath := is_invalid(host, path)
	}

	count(invalid_hostpaths) > 0

	msg := sprintf("hostpaths in the %v are not valid for this namespace: %v. %s", [kind, invalid_hostpaths, input.parameters.errorMsgAdditionalDetails])
}

# Hostname conflict with other namespace Ingress(es), VirtualService(s), or DestinationRule(s) and hostpath not allowed
violation[{"msg": msg}] {
	kind := input.review.kind.kind
	re_match("^(Ingress|VirtualService|DestinationRule)$", kind)
	re_match("^(networking.k8s.io|networking.istio.io)$", input.review.kind.group)

	host := get_hosts()[_]
	path := get_paths()[_]

	not is_allowed(host, path)

	ingress_conflicts := {output |
		conflict := data.inventory.namespace[other_namespace]["networking.k8s.io/v1"].Ingress[other_name]
		conflict.spec.rules[_].host == host
		conflict.metadata.namespace != input.review.object.metadata.namespace
		output := concat("/", ["Ingress", other_namespace, other_name])
	}

	vs_conflicts := {output |
		conflict := data.inventory.namespace[other_namespace]["networking.istio.io/v1beta1"].VirtualService[other_name]
		conflict.spec.hosts[_] == host
		conflict.metadata.namespace != input.review.object.metadata.namespace
		output := concat("/", ["VirtualService", other_namespace, other_name])
	}

	dr_conflicts := {output |
		conflict := data.inventory.namespace[other_namespace]["networking.istio.io/v1beta1"].DestinationRule[other_name]
		conflict.spec.host == host
		conflict.metadata.namespace != input.review.object.metadata.namespace
		output := concat("/", ["DestinationRule", other_namespace, other_name])
	}

	conflicts := (ingress_conflicts | vs_conflicts) | dr_conflicts

	count(conflicts) > 0

	msg := sprintf("%v hostname %v conflicts with existing object(s) in other namespace(s): %v. %s", [kind, host, conflicts, input.parameters.errorMsgAdditionalDetails])
}
