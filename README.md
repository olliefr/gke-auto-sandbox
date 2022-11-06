# Quickly provision a GKE cluster using Terraform

I use this module for proof-of-concept, demo, lab, and other experimental yet realistic deployments of Google Kubernetes Engine.

The general philosophy for the module is to follow best practices for production-grade deployments. Two important deviations are aggressive logging and telemetry collection, and preemptible nodes are used by default to reduce the cost.

## Architecture

Although this deployment is meant for proof-of-concept and experimental work, it implements many of the Google's [cluster security recommendations](https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster).

* The cluster is [VPC-native](https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips) as it uses alias IP address ranges;
* It is a [private cluster], that is its worker nodes do not have public IP addresses;
* The default availability type is _zonal_, but can be changed to _regional_;
* It is _multi-zonal_ as the nodes are allocated in multiple zones;
* It has a _public endpoint_ with access limited to the _list of authorised control networks_;
* It has [Dataplane V2](https://cloud.google.com/blog/products/containers-kubernetes/bringing-ebpf-and-cilium-to-google-kubernetes-engine) enabled so it can enforce Network Policies;
* It uses [preemptible VMs] for worker nodes. This reduces the running cost substantially;
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

* [Terraform](https://www.terraform.io/) 1.3.4 or later. This module is Terraform Cloud compatible;
* A Google Cloud project with the [necessary permissions](#required-permissions);
* The project must be linked to a [billing account].

[billing account]: https://cloud.google.com/billing/docs/concepts#billing_account

### Required permissions

The `owner` basic role on the project would work. The `editor` might but I have not tested it. 

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
zone    = "europe-west2-a"

authorized_networks = [
  {
    cidr_block   = "0.0.0.0/0"
    display_name = "warning-publicly-accessible-endpoint"
  },
]
```

* You _must_ set the `project` ID;
* You _may_ change the `region` and `zone` to your preferred values;
* You _should_ change the values in `authorized_networks` to only allow access from your approved CIDR blocks.

❗ The default value for `authorized_networks` allows public access to the cluster endpoint. You still have to authenticate to perform any action, but it's not best practice to leave the control plane endpoint exposed to the world. So, adjust the `authorized_networks` accordingly.

To find your public IP, you can run `dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com`

Now you can deploy with Terraform (`init` ... `plan` ... `apply`). Enjoy! :shipit:

## Input variables

This module accepts the following input variables.

* `project` is the Google Cloud project resource ID.
* (Optional) The default `region` for all resources.
* (Optional) The default `zone` for all resources.
* (Optional) Cluster `availability_type`: default is `zonal`. Other option is `regional`. Defines the control plane location, as well as the default location for worker nodes.
* (Optional) VPC flow logs: `enable_flow_log`
* (Optional) Use `preemptible` VM instances for cluster nodes. Default is `true`.
* (Optional) `node_cidr_range`
* (Optional) `pod_cidr_range`
* (Optional) `service_cidr_range`
* (Optional) The list of `authorized_networks` representing CIDR blocks allowed to access the cluster's control plane.

## Example workload

Once the infrastructure is provisioned with Terraform, you can deploy the example workload.

* _Online Boutique_ application by Google: [GoogleCloudPlatform/microservices-demo]
* My custom, hardened, version of deployment manifests: [olliefr/gke-microservices-demo]

[GoogleCloudPlatform/microservices-demo]: https://github.com/GoogleCloudPlatform/microservices-demo
[olliefr/gke-microservices-demo]: https://github.com/olliefr/gke-microservices-demo

## Future work

The following list is some ideas for future explorations.

* Deploy by impersonating a service account to validate the list of required roles;
* Create a [private cluster with no public endpoint][pcwnpe] and access the endpoint using [IAP for TCP forwarding];
* Provide an option for [Secret management];
* Configure [Artifact registry];
* Enable [Binary Authorization];
* Replace [preemptible VMs] with [spot VMs];
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
[preemptible VMs]: https://cloud.google.com/compute/docs/instances/preemptible
[spot VMs]: https://cloud.google.com/compute/docs/instances/spot
[Cloud DNS for GKE]: https://cloud.google.com/kubernetes-engine/docs/how-to/cloud-dns
[Shared VPC]: https://cloud.google.com/vpc/docs/shared-vpc
[VPC Service Controls]: https://cloud.google.com/vpc-service-controls/docs/overview
[intranode visibility]: https://cloud.google.com/kubernetes-engine/docs/how-to/intranode-visibility
[Config Connector]: https://cloud.google.com/config-connector/docs/overview
[Config Controller]: https://cloud.google.com/anthos-config-management/docs/concepts/config-controller-overview
[Anthos Service Mesh]: https://cloud.google.com/service-mesh/docs/overview