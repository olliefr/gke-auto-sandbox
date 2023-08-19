# Google Kubernetes Engine (GKE) sandbox

> **Warning**
> This configuration is a research prototype. Use with caution :smiling_imp:

This Terraform configuration deploys a sandbox for experimenting with [GKE Autopilot](https://cloud.google.com/kubernetes-engine) private clusters.

Because it is meant for exploration and demos, some parts are configured differently from what you'd expect to see in a *production* system. The most prominent deviations are:

* A *lot* of telemetry is collected. Logging and monitoring levels are set well above their default values.
* All Google Cloud resources for the cluster are deployed directly from this Terraform module using the latest versions of Terraform and Terraform Google provider.
* Input validation is not a priority.
* Backwards compatibility is non-existent.

<!-- TODO research how Spot VMs work with Autopilot clusters
* [Spot VM instances](https://cloud.google.com/kubernetes-engine/docs/concepts/spot-vms) are used for cluster nodes by default.
-->

You have been warned! It's good fun, though, so feel free to fork and play around with GKE, it's pretty cool tech, in my opinion.

# Useful resources

GKE best practices and other related resources.

* [Terraform for opinionated GKE clusters](https://github.com/terraform-google-modules/terraform-google-kubernetes-engine)
* [Autopilot vs Standard clusters feature comparison](https://cloud.google.com/kubernetes-engine/docs/resources/autopilot-standard-feature-comparison)
* [Best practices for GKE networking](https://cloud.google.com/kubernetes-engine/docs/best-practices/networking)
* [Harden your cluster's security](https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster)
* [Best practices for running cost-optimized Kubernetes applications on GKE](https://cloud.google.com/architecture/best-practices-for-running-cost-effective-kubernetes-applications-on-gke). Includes a great [summary](https://cloud.google.com/architecture/best-practices-for-running-cost-effective-kubernetes-applications-on-gke#summary_of_best_practices) checklist.

## Architecture

Although this deployment is meant for proof-of-concept and experimental work, it implements many of the Google's [cluster security recommendations](https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster).

* It is a [private cluster], so the cluster nodes do not have public IP addresses.
<!-- * It has a _public endpoint_ with access limited to the _list of authorised control networks_; -->
<!-- * It has [Dataplane V2](https://cloud.google.com/blog/products/containers-kubernetes/bringing-ebpf-and-cilium-to-google-kubernetes-engine) enabled so it can enforce Network Policies; -->
<!-- * It uses [Spot VMs](https://cloud.google.com/compute/docs/instances/spot) for worker nodes. This reduces the running cost substantially. -->
* [Cloud NAT][^1] is configured to allow the cluster nodes and pods to access the Internet. So container registries located outside Google Cloud can be used.
* The cluster nodes use a user-managed [least privilege service account].
* The cluster is subscribed to the _Rapid_ [release channel].
* [VPC Flow Logs] are enabled by default on the cluster subnetwork.

Some other aspects which used to be a thing when this sandbox was for deployment of Standard GKE clusters are now ["pre-configured"](https://cloud.google.com/kubernetes-engine/docs/resources/autopilot-standard-feature-comparison) by GKE Autopilot, but it's still useful to remember what they are:

* The cluster is [VPC-native](https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips).
* It has *regional* availability.
* [Shielded GKE nodes] feature is enabled.
* [Secure Boot] and [Integrity Monitoring] are enabled.
* [Workload Identity] is enabled.
* A [hardened node image with `containerd` runtime](https://cloud.google.com/kubernetes-engine/docs/concepts/using-containerd) is used.

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

* [Terraform](https://www.terraform.io/)
* A Google Cloud project with the [necessary permissions](#required-permissions) granted to you.
* The project must be linked to an active [billing account].

[billing account]: https://cloud.google.com/billing/docs/concepts#billing_account

### Permissions required to deploy

Given that this is a research prototype, I am not that fussy about scoping every admin role that is needed to deploy this module. The `roles/owner` IAM basic role on the project would work. The `roles/editor` IAM basic role *might* work but I have not tested it. 

<!--
The operator must have the permissions to enable new services, create service accounts, set IAM bindings at project level.
-->

If you fancy doing it *the hard way* &ndash; and there is time and place for such adventures, indeed &ndash; I hope this starting list of roles will help:

* Kubernetes Engine Admin (`roles/container.admin`)
* Service Account Admin (`roles/iam.serviceAccountAdmin`)
* Compute Admin (`roles/compute.admin`)
* Service Usage Admin (`roles/serviceusage.serviceUsageAdmin`)
* Monitoring Admin (`roles/monitoring.admin`)
* Private Logs Viewer (`roles/logging.privateLogViewer`)
* Moar?!

## Quick start

Clone the repo and you are good to go! You can provide the input variables' values as command-line parameters to Terraform CLI:

```shell
terraform init && terraform apply -var="project=infernal-horse" -var="region=europe-west4"
```

* You _must_ set the Google Cloud project ID and Google Cloud region.
* You _may_ set `authorized_networks` to enable access ot the cluster's endpoint from a public IP address. You still would have to authenticate.

Alternatively, you can create a variable definitions file, such as `env.auto.tfvars` and define the values therein.

> **Note**
> The default value for `authorized_networks` does not allows any public access to the cluster endpoint.

```hcl
project = "<PROJECT_ID>"
region  = "<REGION>"

authorized_networks = [
  {
    cidr_block   = "1.2.3.4/32"
    display_name = "my-ip-address"
  },
]
```

> **Note**
> To find your public IP, you can run the following command
>
>  ```shell
>  dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com
>  ```

Now you can run Terraform (`init` ... `plan` ... `apply`) to deploy. 

Happy hacking! :shipit:

## Input variables

This module accepts the following input variables.

* `project` is the Google Cloud project ID.
* `region` is the Google Cloud region for all deployed resources.
* (Optional) VPC flow logs: `enable_flow_log`
<!-- * (Optional) `use_spot_vms` defines if Spot VMs should be used for cluster nodes. Default is `true`. -->
* (Optional) `node_cidr_range`
* (Optional) `pod_cidr_range`
* (Optional) `service_cidr_range`
* (Optional) The list of `authorized_networks` representing CIDR blocks allowed to access the cluster's control plane.

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

<!-- 
```
TODO enable audit log entries for used APIs:
https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam#google_project_iam_audit_config
```

```
TODO add moar Terraform outputs to give a decent summary of what the cluster is about (CIDR ranges, etc)
```
-->

## Future work

The following list is some ideas for future explorations.

* Deploy by impersonating a service account to validate the list of required admin roles;
* Create a [private cluster with no public endpoint][pcwnpe] and access the endpoint using [IAP for TCP forwarding];
* Provide an option for [Secret management];
* Configure [Artifact registry];
* Enable [Binary Authorization];
* [Shared VPC] set-up;
* [VPC Service Controls];
* Enable [intranode visibility] on a cluster;
* Set up the [Config Connector] (or use the [Config Controller]);
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
