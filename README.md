# GateKeeper Policies

Policies that are to be enforced by [GateKeeper](https://github.com/open-policy-agent/gatekeeper) for the Kubernetes Platform.

> Note: Gatekeeper is a validating / mutating webhook that enforces CRD-based policies executed by the Open Policy Agent.

## Policies

### General

This repo contains general policies that can be used to enforce common Kubernetes requirements.

| Control Aspect                   | Gatekeeper Constraint Template                                               |
| -------------------------------- | ---------------------------------------------------------------------------- |
| Block Operations                 | [block-operations](general/block-operations)                                 |
| Block Wildcard Ingress           | [block-wildcard-ingress](general/block-wildcard-ingress)                     |
| Container Allowed Images         | [container-allowed-images](general/container-allowed-images)                 |
| Pod Disruption Budget            | [pod-disruption-budget](general/pod-disruption-budget)                       |
| Restrict Hostnames               | [restrict-hostnames](general/restrict-hostnames)                             |
| Storage Class                    | [storage-class](general/storage-class)                                       |

### Pod Security Policies

This repo contains common policies replacing the deprecated `PodSecurityPolicy` into Constraint Templates using [GateKeeper](https://github.com/open-policy-agent/gatekeeper).

| Control Aspect                     | Gatekeeper Constraint Template                                                             |
| ---------------------------------- | ------------------------------------------------------------------------------------------ |
| Metadata Restrictions              | [metadata-restrictions](pod-security-policy/metadata-restrictions)                         |
| Restrict Pod Annotations           | [restrict-pod-annotations](pod-security-policy/restrict-pod-annotations)                   |
| Restrict Pod Labels                | [metadata-restrictions](pod-security-policy/restrict-pod-labels)                           |

### Service Mesh

This repo contains a set of common policies that can be used to enforce specific Service Mesh features.

| Control Aspect      | Gatekeeper Constraint Template                          |
| ------------------- | ------------------------------------------------------- |
| Gateway             | [gateway](service-mesh/gateway)                         |
| Traffic Policy      | [traffic-policy](service-mesh/traffic-policy)           |

## Testing

When creating a Policy, there are currently three ways of testing them:

### OPA Tests

The `opa` CLI can be used to run [tests](https://www.openpolicyagent.org/docs/latest/policy-testing) on policies.
This can be very useful since Open Policy Agent allows for easy mocking of data via the [`with` keyword](https://www.openpolicyagent.org/docs/latest/policy-testing/#data-and-function-mocking).

> These types of tests are best suited for policies which require access to data not available in the [`AdmissionReview`](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#webhook-request-and-response) API but accessed via [Gatekeeper's data replication features](https://open-policy-agent.github.io/gatekeeper/website/docs/sync).

To take advantage of automatic test running and the automatic copying of `rego` into a  `ConstraintTemplate`, the following structure needs to be followed:
- Ensure that the `ConstraintTemplate` is in a file named `template.yaml` at the root of your policy's folder
- Ensure that the `rego` files are in a folder called `rego`
  - For example: [general/restrict-hostnames/rego](./general/restrict-hostnames/rego/)
- Ensure that the `rego` that should be injected into the `ConstraintTemplate` is named `src.rego`
- Run the [`rego.sh`](./rego.sh) script to run tests and copy your source code into `template.yaml`
  - Note: requires the [`yq`](https://github.com/mikefarah/yq) utility

### Integration Tests

Integration tests are run as part of the GitHub Actions. These deploy policies to a `k3s` cluster using the [BATS](https://github.com/bats-core/bats-core) framework. It deploys the `ConstraintTemplate` for the policy, a single CustomResource of the CRD derived from the `ConstraintTemplate`, and two resources representing a passing and a failing scenario.

To take advantage of this system create the following:
- Ensure that the `ConstraintTemplate` is in a file named `template.yaml` at the root of your policy's folder
- Create a folder named `example` at the root of your policy's folder
- In the `example` folder:
  - Create a file named `constraint.yaml` with the `CustomResource` representing an implemented policy
  - Create a file named `allowed.yaml` with a resource that should pass the policy
  - Create a file named `disallowed.yaml` with a resource that should not pass the policy

### Gator

[`gator`](https://open-policy-agent.github.io/gatekeeper/website/docs/gator) is a recent addition to Gatekeeper allowing for the creation of test suites that can be run locally.

[`gator` test suites](https://open-policy-agent.github.io/gatekeeper/website/docs/gator#writing-test-suites) will be run automatically as part of the CI.

## Links

- [Rego Playground](https://play.openpolicyagent.org/)

## Acknowledgements

- [Anthos](https://github.com/GoogleCloudPlatform/acm-policy-controller-library)
- [Azure Policy](https://github.com/Azure/azure-policy/tree/master/built-in-references/Kubernetes)
- [Community Policy](https://github.com/Azure/Community-Policy)
- [Open Policy Agent](https://github.com/open-policy-agent/gatekeeper-library)
