# Google Kubernetes Engine sandbox

> **Warning**
> This is an **experimental rig**, not a blueprint for **production**. Think before you deploy :smiling_imp:

This [Terraform](https://www.terraform.io/) module deploys a complete environment for experimentation with [GKE Autopilot](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview) clusters. All you need is an existing Google Cloud project.

The environment consists of the following parts:

* Regional GKE Autopilot cluster. The cluster nodes are private and access to the public endpoint is disabled.
* Cloud NAT configuration to enable *outbound* Internet access for cluster nodes.
* Cloud DNS configuration to enable Private Google Access (PGA) on the cluster's subnet.
* Tiny Linux-based bastion host with a private IP. The host is not directly accessible from the Internet.
* Identity-Aware Proxy (IAP) configuration for connecting to the bastion host *from anywhere* in a *secure* manner.
* Least-privileged service accounts for the cluster nodes and for the bastion host.
* A VPC network for the cluster and the bastion host.
* Firewall rules.

Some notable configuration choices:

* This Terraform module is self-contained. Happy hacking!
* Recent versions of Terraform and Terraform Google provider are used. Play with the latest features!
* Some resources are deployed with [Google-beta provider](https://registry.terraform.io/providers/hashicorp/google-beta/latest) to enable access to cutting-edge features.
* A *lot* of logs and metrics are collected: VPC Flow Logs, firewall rules logging, Cloud NAT logging, IAP access logs, and more.
* No maintenance schedule is set for the cluster. This avoids delays when making changes to cluster configuration.
* Backwards compatibility between the module versions should not be expected.

<!-- 

# Useful resources

Links to documentations, best practices, and other helpful resources.

* [Private clusters in GKE](https://cloud.google.com/kubernetes-engine/docs/concepts/private-cluster-concept)

A *private cluster* is a type of cluster that only depends on internal IP addresses. Nodes, Pods, and Services in a private cluster require unique subnet IP address ranges. To provide outbound internet access for certain private nodes, [Cloud NAT](https://cloud.google.com/nat/docs/overview) is used.


* [Autopilot vs Standard clusters feature comparison](https://cloud.google.com/kubernetes-engine/docs/resources/autopilot-standard-feature-comparison)
* [GKE Autopilot security capabilities](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-security)
* [Best practices for GKE networking](https://cloud.google.com/kubernetes-engine/docs/best-practices/networking)
* [Security overview](https://cloud.google.com/kubernetes-engine/docs/concepts/security-overview)
* [Harden your cluster's security](https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster)
* [Best practices for running cost-optimized Kubernetes applications on GKE](https://cloud.google.com/architecture/best-practices-for-running-cost-effective-kubernetes-applications-on-gke). Includes a great [summary checklist](https://cloud.google.com/architecture/best-practices-for-running-cost-effective-kubernetes-applications-on-gke#summary_of_best_practices).
* [Terraform for opinionated GKE clusters](https://github.com/terraform-google-modules/terraform-google-kubernetes-engine)
* [Production grade GKE network deployment, in 3 easy steps](https://medium.com/@pbijjala/3-key-best-practices-for-gke-deployment-4fa132e157e2).

-->

<!-- 
## Architecture

Although this deployment is meant for proof-of-concept and experimental work, it implements many of the Google's [cluster security recommendations](https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster).

* It is a [private cluster] so the cluster nodes do not have public IP addresses and there is no public endpoint for the control plane.
* [Cloud NAT] is configured to allow the cluster nodes and pods to access the Internet. So container registries located outside Google Cloud can be used.
* The cluster nodes use a user-managed [least privilege service account].
* [VPC Flow Logs] are enabled by default on the cluster and admin subnetworks.

Some other aspects which used to be a thing when this sandbox was for deployment of Standard GKE clusters are now ["pre-configured"](https://cloud.google.com/kubernetes-engine/docs/resources/autopilot-standard-feature-comparison) by GKE Autopilot, but it's still useful to remember what they are:

* The cluster is [VPC-native](https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips).
* It has *regional* availability.
* [Shielded GKE nodes] feature is enabled.
* [Secure Boot] and [Integrity Monitoring] are enabled.
* [Intranode visibility] is enabled.
* [Dataplane V2](https://cloud.google.com/blog/products/containers-kubernetes/bringing-ebpf-and-cilium-to-google-kubernetes-engine) is enabled. It also provides network policy enforcement and logging.
* [Workload Identity] is enabled.
* A [hardened node image with `containerd` runtime](https://cloud.google.com/kubernetes-engine/docs/concepts/using-containerd) is used.
* [Spot VMs](https://cloud.google.com/kubernetes-engine/docs/concepts/spot-vms) are provisioned by Autopilot automatically when [Spot Pods](https://cloud.google.com/kubernetes-engine/docs/how-to/autopilot-spot-pods) are requested.

[least privilege service account]: https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster#use_least_privilege_sa
[Cloud NAT]: https://cloud.google.com/nat/docs/overview
[private cluster]: https://cloud.google.com/kubernetes-engine/docs/concepts/private-cluster-concept
[Shielded GKE nodes]: https://cloud.google.com/kubernetes-engine/docs/how-to/shielded-gke-nodes
[release channel]:  https://cloud.google.com/kubernetes-engine/docs/concepts/release-channels
[Secure Boot]: https://cloud.google.com/compute/shielded-vm/docs/shielded-vm#secure-boot
[Integrity Monitoring]: https://cloud.google.com/compute/shielded-vm/docs/shielded-vm#integrity-monitoring
[Workload Identity]: https://cloud.google.com/kubernetes-engine/docs/concepts/workload-identity
[VPC Flow Logs]: https://cloud.google.com/vpc/docs/flow-logs

## Requirements
-->

<!-- TODO ideally you want the versions to be auto-generated (Terraform plus providers) -->
<!-- 
* [Terraform](https://www.terraform.io/), obviously.
* A Google Cloud project with the [necessary permissions](#required-permissions) granted to you.
* The project must be linked to an active [billing account].

[billing account]: https://cloud.google.com/billing/docs/concepts#billing_account

### Permissions required to deploy

Given that this is a research prototype, I am not that fussy about scoping every admin role that is needed to deploy this module. The `roles/owner` IAM basic role on the project would work. The `roles/editor` IAM basic role *might* work but I have not tested it. 

-->

<!--
The operator must have the permissions to enable new services, create service accounts, set IAM bindings at project level.
-->

<!-- 

If you fancy doing it *the hard way* &ndash; and there is time and place for such adventures, indeed &ndash; I hope this starting list of roles will help:

* Kubernetes Engine Admin (`roles/container.admin`)
* Service Account Admin (`roles/iam.serviceAccountAdmin`)
* Compute Admin (`roles/compute.admin`)
* Service Usage Admin (`roles/serviceusage.serviceUsageAdmin`)
* Monitoring Admin (`roles/monitoring.admin`)
* Private Logs Viewer (`roles/logging.privateLogViewer`)
* Moar?!
-->

## Quick start

Clone the repo and you are good to go!

Only two input variables are required, the rest is optional with sensible and secure default values.

Create the variable definitions file `terraform.tfvars` with the following values:

```hcl
google_project = "<PROJECT_ID>"
google_region  = "<REGION>"
```

Note that you'd have to provide your own values for the variables 😉

Now you can run Terraform as you normally would. Happy hacking! :shipit: :rocket:

<!-- 
## Input variables

> **Warning**
> TODO set up auto-generation of this section 

The input variables are currently documented in [`variables.tf`](./variables.tf)

## Example workload

> **Warning**
> This section is grossly out-of-date!

Once the infrastructure is provisioned with Terraform, you can deploy the example workload.

* _Online Boutique_ application by Google: [GoogleCloudPlatform/microservices-demo]
* **out-of-date** My custom, hardened, version of deployment manifests: [olliefr/gke-microservices-demo]

[GoogleCloudPlatform/microservices-demo]: https://github.com/GoogleCloudPlatform/microservices-demo
[olliefr/gke-microservices-demo]: https://github.com/olliefr/gke-microservices-demo

## Code structure

> **Warning**
> This section is grossly out-of-date!

This module runs in two stages, using two (aliased) instances of Terraform Google provider.

The first stage, named the _seed_, is self-contained in `010-seed.tf`. It runs with user
credentials via ADC and sets up the foundation for the deployment that follows. The required
services are enabled at this stage, and a least privilege IAM service account is provisioned
and configured. At the end of the seed stage, a second instance of Terraform Google provider
is initialised with the service account's credentials.

The following stage deploys the cluster resources using service account impersonation.

This deployment architecture serves three aims:

* Short feedback loop. Everything is contained in a single Terraform module so is 
  simple to deploy and update.
* Deploying using a least privilege service account. This reduces the risk of 
  hitting a permission error on deployment into "production", which is usually done
  by a locked-down service account, as compared to deployment into "development" environment,
  which was done with user's Google account identity that usually has very broad permissions
  on the project (`Owner` or `Editor`). [Inspiration](https://cloud.google.com/blog/topics/developers-practitioners/using-google-cloud-service-account-impersonation-your-terraform-code).
* The module can be used with "long-life" Google Cloud projects that are "repurposed" from one
  experiment to another. The explicit declaration of dependencies, where it was necessary, allows
  Terraform to destroy the resources in the right order, when requested. 

```
# 000-versions: Terraform and provider versions and configuration
# 010-seed: configure the project and provision a least privilege service account for deploying the cluster
# 030-cluster-node-sa: provision and configure a least privilege service account for cluster nodes
# 040-network: create a VPC, a subnet, and configure network and firewall logs.
# 050-nat: resources that provide NAT functionality to cluster nodes with private IP addresses.
# 060-cluster: create a GKE cluster (Standard)
```

-->

<!-- 
```
TODO enable audit log entries for used APIs:
https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam#google_project_iam_audit_config
```

```
TODO add moar Terraform outputs to give a decent summary of what the cluster is about (CIDR ranges, etc)
```
-->

## (Deep Dive) IP address ranges


> **Note**
> This **optional** section provides two examples of reasoning that goes into defining the cluster's IP ranges.

For GKE Autopilot clusters, VPC-native traffic routing is enabled by default. See [VPC-native clusters](https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips).

[Pod CIDR ranges in Autopilot clusters](https://cloud.google.com/kubernetes-engine/docs/how-to/flexible-pod-cidr#cidr_settings_for_clusters) lists the default settings for Autopilot cluster CIDR sizes.

* Autopilot has a maximum Pods per node of [32](https://cloud.google.com/kubernetes-engine/quotas#limits_per_cluster). 
* Because of Pod churn, twice that number of IP addresses may be required. So, there are `64` IP addresses allocated per node, or `2^6`.

Let's consider two scenarios - big and small. A [CIDR range visualizer](https://cidr.xyz/) will be useful!

### Go **BIG**!

* If we'd like to have `1024` cluster nodes, or `2^10`, the total required IP space for Pods is `2^10 * 2^6 = 2^16`.
* The VPC subnet secondary IP range for Pods does not have further restrictions.
* So the size of the Pods CIDR is `/16`. I pick `192.168.0.0/16`.
* The primary range must accommodate `2^10` nodes and because it's the primary range `4` IP addresses are reserved.
* So, `2^11` bits are needed for the host part to represent the nodes. This leaves with `32-11=21` bits for the network part.
* I choose `10.0.248.0/21` for the cluster subnet primary IP range.
* In the third octet: `248 = 2^7 + 2^6 + 2^5 + 2^4 + 2^3`, and the lowest three bits are part of the host number.

To sum up, in the **BIG** scenario, we have:

* Nodes: `cluster_subnetwork_ipv4_cidr = "10.0.248.0/21"`. This can get us `2044` nodes. [Limits per cluster](https://cloud.google.com/kubernetes-engine/quotas#limits_per_cluster) state that running more than 400 nodes may require lifting a cluster size quota.
* Pods: `pods_ipv4_cidr = "192.168.0.0/16"`. This gives `65536` Pods.
* Services: `services_ipv4_cidr = null` or unset and so it gets the default value of `34.118.224.0/20`. This accommodates up to `4096` Services.

This is, *obviously*, too big for a sandbox 😈

### Go *smol*

* Let's scale down the cluster node number to `128`, or `2^7`. The total required IP space for Pods is `2^7 * 2^6 = 2^13`.
* So the size of the Pods CIDR is `/(32 - 13) = /19`. I pick `192.168.0.0/19` for convenience.
* The primary range must accommodate `2^7` nodes and because it's the primary range `4` IP addresses are reserved.
* At this small scale those four addresses actually make a difference - one can't fit `128` nodes into `7` bits.
* So, `2^8` bits are needed for the host part to represent the nodes. This leaves with `32-8=24` bits for the network part.
* I choose `10.0.0.0/24` for the cluster subnet primary IP range.
* The last octet provides `2^8 - 4 = 255 - 4 = 251` cluster nodes.

This leaves us with:

* Nodes: `cluster_subnetwork_ipv4_cidr = "10.0.0.0/24"`. This can get us `252` nodes. 
* Pods: `pods_ipv4_cidr = "192.168.0.0/19"`. This gives `8192` Pods.
* Services: `services_ipv4_cidr = null` or unset and so it gets the default value of `34.118.224.0/20`. This accommodates up to `4096` Services.

These values are much more reasonable for the sandbox 😉 So they are the default values for Terraform input variables.

### Custom IP range for Services

In the preceding two scenarios, I went with the Google-managed IP range for Services. This was done for convenience. Should I wish to provide my own custom value, it is possible. I'd probably go for `/20` anyway.

## Future work

Just a place to jot down some ideas for future explorations...

* Deploy by impersonating a service account to validate the list of required admin roles;
* Create a [private cluster with no public endpoint][pcwnpe] and access the endpoint using [IAP for TCP forwarding];
* Provide an option for [Secret management];
* Configure [Artifact registry];
* Enable [Binary Authorization];
* Try deploying with GPUs.
* Try deploying [Spot Pods].
* [Shared VPC] set-up;
* [VPC Service Controls];
* Set up the [Config Connector] (or use the [Config Controller]);
* Explore [Cloud DNS for GKE] option;
* IPv6 set-up;
* Explore [Anthos Service Mesh] (managed Istio);
* Use Terraform's new "check" conditions to validate if `constraints/compute.vmExternalIpAccess` is set to restrict public IP addresses on the project and refuse to create public clusters

[pcwnpe]: https://cloud.google.com/kubernetes-engine/docs/how-to/private-clusters#private_cp
[IAP for TCP forwarding]: https://cloud.google.com/iap/docs/using-tcp-forwarding
[Secret management]: https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster#secret_management
[Artifact registry]: https://cloud.google.com/artifact-registry/docs/overview
[Binary authorization]: https://cloud.google.com/binary-authorization/docs
[Cloud DNS for GKE]: https://cloud.google.com/kubernetes-engine/docs/how-to/cloud-dns
[Shared VPC]: https://cloud.google.com/vpc/docs/shared-vpc
[VPC Service Controls]: https://cloud.google.com/vpc-service-controls/docs/overview
[intranode visibility]: https://cloud.google.com/kubernetes-engine/docs/how-to/intranode-visibility
[Config Connector]: https://cloud.google.com/config-connector/docs/overview
[Config Controller]: https://cloud.google.com/anthos-config-management/docs/concepts/config-controller-overview
[Anthos Service Mesh]: https://cloud.google.com/service-mesh/docs/overview

<!--
TODO review, redraft, and find a new home for this information

# IP address range planning
# https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips
#
# Subnet primary IP address range (used for cluster nodes)
# Once created, it
#   + can expland at any time
#   - cannot shrink
#   - cannot change IP address scheme
# Thus, it makes sense to start small. Let's say 16 nodes (which is 2^4).
# Adresses for 16 nodes require (4+1) bits to represent (+1 is to accomodate for 4 reserved addresses),
# thus the mask /(32-5) = /27. It's a bit more than what's needed, but losing
# a bit would reduce the number of allowed nodes to 12. So, /27 it is.
# So, the CIDR block for the primary IP adderess range (cluster nodes IP addresses) is /27.
#
# Next, the pod address range. There's a limit on the number of pods each node can host,
# we change it from the default value of 110 to 32 (which is the default value for Autopilot clusters),
# and it's more reasonable, in my opinion. Now that we know that each node can host no more than 32 = 2^5
# pods, and we know that we can have at most 16 = 2^4 nodes, the total address space size is 2^5 * 2^4 = 2^9,
# or 512. But this does not take into account the x2 rule for pod IP addresses (pods starting up and shutting
# down). Thus, the true smallest value our pod IP address range can have is 2 * 512 = 1024, or 2^10.
# This dictates the CIDR mask of /(32 - 10) = /22. What are the implications for the future scalability?
#   + it is possible to replace a subnet's secondary IP address range
#   - doing so is not supported because it has the potential to put the cluster in an unstable state
#   + however, you can create additional Pod IP address ranges using discontiguous multi-Pod CIDR
# So, if we were really short of IP addresses, we could stop at /22 and use the discontiguous multi-Pod CIDR
# feature as and when needed. But we are not short of addresses, so I am going to upgrade /22 to /19, increasing
# the Pod IP range eightfold (giving up three bits on the network part of the address).
#
# Finally, the Services secondary range. This range cannot be changed as long as a cluster uses it for Services (cluster IP addresses).
# Unlike node and Pod IP address ranges, each cluster must have a unique subnet secondary IP address range for Services and cannot be sourced from a shared primary or secondary IP range.
# On the other hand, we are not short of IP address space, and we don't anticipate having thousands and thousands of services.
# Thus, the default (as if the secondary IP range assignment method was managed by GKE) size of /20, giving 4096 services, is good enough.
-->

## Contributions

This is a personal sandbox so I am unlikely to accept *unexpected* pull requests. But if you have any feedback, please feel free to reach out! 😊

## Let's connect

If you have any questions or feedback on this module, let's connect!

* Email: <oliver@devilmicelabs.com>
* LinkedIn: [in/ofr](https://www.linkedin.com/in/ofr/)
* Twitter: [nocturnalgopher](https://twitter.com/nocturnalgopher)
