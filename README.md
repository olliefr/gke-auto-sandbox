# Google Kubernetes Engine (GKE) sandbox

* **Project State: Prototyping**
* For more information on project states and SLAs, see [this documentation](https://github.com/chef/chef-oss-practices/blob/d4333c01570eae69f65470d58ed9d251c2e552a3/repo-management/repo-states.md).

This is my sandbox for [Google Kubernetes Engine](https://cloud.google.com/kubernetes-engine) (GKE). 

It's a weird one &ndash; on the one hand, I aim to follow best practices and keep it as "production-ready" as my skill level and experience allows. On the other hand, *this is a sandbox* for experimentation and demos, not a production system. Thus some aspects of it are configured differently from what you'd expect to see in a production system.

The most imporant deviations from a "production-grade" system are:

* Logging and monitoring data production is well above default levels.
* [Spot VM instances](https://cloud.google.com/compute/docs/instances/spot) are used for cluster nodes by default.
* Terraform: all Google Cloud assets are deployed from a single Terraform module.
* Terraform: very recent versions of Terraform and its providers are used.
* Terraform: some input variables are not validated.

Which are all acceptable trade-offs for my use case. And it's quite fun to play with.

# Useful resources

These resources are useful for increasing one's awareness of what is considered "best practice" when it comes to GKE.

* [Best practices for GKE networking](https://cloud.google.com/kubernetes-engine/docs/best-practices/networking)
* [Harden your cluster's security](https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster)
* [Best practices for running cost-optimized Kubernetes applications on GKE](https://cloud.google.com/architecture/best-practices-for-running-cost-effective-kubernetes-applications-on-gke). Includes a great [summary](https://cloud.google.com/architecture/best-practices-for-running-cost-effective-kubernetes-applications-on-gke#summary_of_best_practices) checklist.

## Architecture

Although this deployment is meant for proof-of-concept and experimental work, it implements many of the Google's [cluster security recommendations](https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster).

* The cluster is [VPC-native](https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips) as it uses alias IP address ranges;
* It is a [private cluster], that is its worker nodes do not have public IP addresses;
* The default availability type is _zonal_, but can be changed to _regional_;
* It is _multi-zonal_ as the nodes are allocated in multiple zones;
* It has a _public endpoint_ with access limited to the _list of authorised control networks_;
* It has [Dataplane V2](https://cloud.google.com/blog/products/containers-kubernetes/bringing-ebpf-and-cilium-to-google-kubernetes-engine) enabled so it can enforce Network Policies;
* It uses [Spot VMs](https://cloud.google.com/compute/docs/instances/spot) for worker nodes. This reduces the running cost substantially;
* The worker nodes' outbound Internet access is via [Cloud NAT][^1];
* [Cloud NAT] is enabled on the cluster subnet. This enables the cluster nodes' access to container registries located outside Google Cloud Platform; 
* A [hardened node image with `containerd` runtime](https://cloud.google.com/kubernetes-engine/docs/concepts/using-containerd) is used;
* The nodes use a user-managed [least privilege service account];
* [Shielded GKE nodes] feature is enabled;
* [Secure Boot] and [Integrity Monitoring] are enabled on cluster nodes;
* The cluster is subscribed to _Rapid_ [release channel];
* [Workload Identity] is supported;
* [VPC Flow Logs] are enabled by default on the cluster's subnet;

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

<!-- TODO ideally you want the versions to be auto-generated (Terraform plus providers) -->

* [Terraform](https://www.terraform.io/) 1.3.4 or later.
* A Google Cloud project with the [necessary permissions](#required-permissions) granted to you;
* The project must be linked to a [billing account].

[billing account]: https://cloud.google.com/billing/docs/concepts#billing_account

### Required permissions

The `owner` basic role on the project would work. The `editor` might but I have not tested it. 

<!--
The operator must have the permissions to enable new services, create service accounts, set IAM bindings at project level.
-->

**Alternatively**, the following roles are required at project level.

* Kubernetes Engine Admin (`roles/container.admin`)
* Service Account Admin (`roles/iam.serviceAccountAdmin`)
* Compute Admin (`roles/compute.admin`)
* Service Usage Admin (`roles/serviceusage.serviceUsageAdmin`)
* Monitoring Admin (`roles/monitoring.admin`)
* Private Logs Viewer (`roles/logging.privateLogViewer`)
* Moar?!

## Quick start

Clone the repo and create the variable definitions file `env.auto.tfvars` with the following content.

```hcl
project = "???"
region  = "europe-west2"
location = "europe-west2"

authorized_networks = [
  {
    cidr_block   = "0.0.0.0/0"
    display_name = "warning-publicly-accessible-endpoint"
  },
]
```

* You _must_ set the `project` ID;
* You _may_ change the `region` to your preferred values;
* You _should_ change the values in `authorized_networks` to only allow access from your approved CIDR blocks.

❗ The default value for `authorized_networks` allows public access to the cluster endpoint. You still have to authenticate to perform any action, but it's not best practice to leave the control plane endpoint exposed to the world. So, adjust the `authorized_networks` accordingly.

To find your public IP, you can run `dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com`

Now you can deploy with Terraform (`init` ... `plan` ... `apply`). Enjoy! :shipit:

## Input variables

This module accepts the following input variables.

* `project` is the Google Cloud project resource ID.
* (Optional) The default `region` for all resources.
* (Optional) Cluster `availability_type`: default is `zonal`. Other option is `regional`. Defines the control plane location, as well as the default location for worker nodes.
* (Optional) VPC flow logs: `enable_flow_log`
* (Optional) `use_spot_vms` defines if Spot VMs should be used for cluster nodes. Default is `true`.
* (Optional) `node_cidr_range`
* (Optional) `pod_cidr_range`
* (Optional) `service_cidr_range`
* (Optional) The list of `authorized_networks` representing CIDR blocks allowed to access the cluster's control plane.

## Example workload

Once the infrastructure is provisioned with Terraform, you can deploy the example workload.

* _Online Boutique_ application by Google: [GoogleCloudPlatform/microservices-demo]
* **out-of-date** My custom, hardened, version of deployment manifests: [olliefr/gke-microservices-demo]

[GoogleCloudPlatform/microservices-demo]: https://github.com/GoogleCloudPlatform/microservices-demo
[olliefr/gke-microservices-demo]: https://github.com/olliefr/gke-microservices-demo

## Code structure

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

```
TODO enable audit log entries for used APIs:
https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam#google_project_iam_audit_config
```

```
TODO add moar Terraform outputs to give a decent summary of what the cluster is about (CIDR ranges, etc)
```

## Future work

The following list is some ideas for future explorations.

* Deploy by impersonating a service account to validate the list of required roles;
* Create a [private cluster with no public endpoint][pcwnpe] and access the endpoint using [IAP for TCP forwarding];
* Provide an option for [Secret management];
* Configure [Artifact registry];
* Enable [Binary Authorization];
* [Shared VPC] set-up;
* [VPC Service Controls];
* Enable [intranode visibility] on a cluster;
* Set up [Config Connector] (or use [Config Controller]);
* Explore [Cloud DNS for GKE] option;
* IPv6 set-up;
* Explore [Anthos Service Mesh] (managed Istio);

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
